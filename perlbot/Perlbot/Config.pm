package Perlbot::Config;


use strict;
use Carp;
use XML::Simple;
use Perlbot::Utils;

use vars qw($AUTOLOAD %FIELDS);
use fields qw(_filename _readonly _config _slaves);

sub new {
  my $class = shift;
  my ($filename, $readonly) = (@_);

  my $self = fields::new($class);

  $self->_filename = $filename;
  $self->_readonly = $readonly ? 1 : undef;
  $self->_config = {};
  $self->_slaves = [];

  # if we didn't get a filename, just send back a config object
  # otherwise
  #   try to load the config
  #   if we can't, then return undef

  if (!$filename) {
    return $self;
  } else {
    $self->load or $self = undef;
    return $self;
  }

}

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $AUTOLOAD;

  $field =~ s/.*:://;

  if(!exists($FIELDS{$field})) {
    return;
  }

  debug("AUTOLOAD:  Got call for field: $field", 15);

  $self->{$field};
}

sub load {
  my ($self) = @_;

  return $self->_config = read_generic_config($self->_filename);
}


sub save {
  my ($self) = @_;

  debug("Config::save: attempting to save " . $self->{_filename} . " ...");
  if ($self->_readonly) {
    debug("  Config object is read-only; aborting");
    return 0;
  }
  my $ret = write_generic_config($self->_filename, $self->_config);
  debug($ret ? "  success" : "  failure");
  return $ret;
}


# fetch data from the config
# params:
#   A list of hash keys and array indices that leads down the config tree
#   to the desired point.
# returns:
#   For a "leaf" scalar value, the scalar itself.  Otherwise, a reference
#   to the requested mid-level hash or array.  The method call may be used
#   as an lvalue to set the value in the config object!
# notes:
#   A useful idiom is to use the => operator between parameters.  Thus you
#   may omit quotes around barewords (except for the rightmost one), and
#   it's also a nice visual representation of what you're asking for.
#   ALSO: if you have a nested object in your config with only one
#   instance (like the "bot" object in the base config) then you may omit
#   the 0 in between hash key parameters. (see last few examples below)
# examples:
#   _value('channel')                  # hashref of channels, keyed on name
#   _value(channel => '#perlbot')      # hashref of single channel's fields
#   _value(channel => '#perlbot' => 'op')                 # arrayref of ops
#   foreach (@{_value(channel=>'#perlbot'=>'op')}) {...}  # same
#   _value(bot => 'nick')              # omitting the 0
#   _value(bot => 0 => 'nick')         # this works but the 0 isn't needed
#   _value(bot => 'nick') = 'NewNick'  # assignment

# TODO: make sure that when a non-existent entity is queried, no
#       hash or array entries spring into existence!

sub _value : lvalue {
  my ($self, @keys) = @_;
  my ($current, $key, $type, $ref);

  debug("_value: " . join('=>', @keys), 9);

  # $current is a "pointer", iterated down the tree
  $current = $self->_config;
  # $ref is a reference to whatever $current is storing
  $ref = \$self->_config;

  # loop over the list of keys we got
  while (defined ($key = shift @keys)) {
    # grab what kind of reference the current thing is
    $type = ref($current);
    if ($type eq 'ARRAY') {
      # check to see if $key is a non-integer (ints required for array indexing)
      if ($key =~ /\D/) {
        # special case for singleton objects, so the 0 index can be
        # omitted as the second parameter, e.g. this lets you write
        # _value('bot','nick') instead of _value('bot',0,'nick)
        if (@$current == 1) {
          unshift(@keys, $key);
          $key = 0;
        } else {
          # otherwise, complain and return undef
          carp "non-integer key specified for array lookup ($key)";
          return undef;
        }
      }
      # "move pointer" down to next level
      if (exists $current->[$key]) {
        $ref = \$current->[$key];
        $current = $$ref;
      } else {
        # non-existent branch; return undef
        $current = $ref = undef;
        last;        
      }
    } elsif ($type eq 'HASH') {
      # no validity checks here; a hash key could be anything.
      # "move pointer" down to next level
      if (exists $current->{$key}) {
        $ref = \$current->{$key};
        $current = $$ref;
      } else {
        # non-existent branch; return undef
        $current = $ref = undef;
        last;
      }
    ### Proxy stuff for the future
    #} elsif (UNIVERSAL::isa($ref, 'Perlbot::Config::Proxy')) {
    #  # we've hit a proxy config object.  pass the rest of the keys to
    #  # it and return whatever it spits back.
    #  $ref = $ref->get(@keys);
    #  last;
    } else {
      # if we get here, we've reached a "leaf" in the tree but there are
      # still more keys to deal with... that's bad.  complain and stop
      # iterating.  we will return undef.
      debug("_value: extra config keys specified: " . join('=>', $key, @keys));
      $current = $ref = undef;
      last;
    }
  }

  # Dereferencing $ref (and omitting 'return'!) is how we get the lvalue
  # stuff to work, so don't touch this unless you know what you're doing!
  $ref or return undef;
  $$ref;
}

# XXX: temporary stub until ->value calls are removed from the codebase
sub value {
  my $self = shift;

  debug("value: deprecated method called");
  $self->_value(@_);
}

sub exists {
  my $self = shift;

  return defined $self->_value(@_);
}

sub get {
  my $self = shift;

  my $ret = $self->_value(@_);
  if (ref $ret) {
    debug("get: request for non-leaf node: ". join('=>', @_));
  }
  return $ret;
}

sub set {
  my $self = shift;
  my $value = shift;

  my $ret = $self->_value(@_);
  if (ref $ret) {
    debug("set: request for non-leaf node: ". join('=>', @_));
  }
  $self->_value(@_) = $value;
}

# only use the array_ and hash_ methods on arrays of regular scalars
# (i.e. no sub-objects)

sub array_get {
  my $self = shift;

  return @{$self->_value(@_)};
}

sub array_push {
  my $self = shift;
  my $value = shift;

  my $arrayref = $self->_value(@_);
  push @$arrayref, $value;
}

sub array_delete {
  my $self = shift;
  my $value = shift;

  @{$self->_value(@_)} = grep {$_ ne $value} $self->_value(@_);
}


sub hash_get_keys {
  my $self = shift;

  return keys %{$self->_value(@_)};
}

# XXX: should this create a full subtree, or just extend an existing branch
#        by one level as it does now?
sub hash_create {
  my $self = shift;
  my $key = pop;

  my $hashref = $self->_value(@_);
  $hashref->{$key} = {};
}

sub hash_delete {
  my $self = shift;
  my $key = pop;

  my $hashref = $self->_value(@_);
  delete $hashref->{$key};
}



1;

