package Perlbot::Config;


use strict;
use Carp;
use XML::Simple;
use Perlbot::Utils;


sub new {
  my $class = shift;
  my ($filename) = (@_);

  my $self = {
    _filename => $filename,
    _config => {},
  };

  bless $self, $class;

  $self->load;

  return $self;
}


sub load {
  my ($self) = @_;

  $self->{_config} = read_generic_config($self->{_filename});
}


sub save {
  my ($self) = @_;

  write_generic_config($self->{_filename}, $self->{_config});
}


# fetch data from the config
# params:
#   a list of hash keys and array indices that leads down the config tree
#   to the desired point
# returns:
#   For a "leaf" scalar value, the scalar itself.  Otherwise, a reference
#   to the requested mid-level hash or array.  If called in array context
#   and the requested object is an array, an array will be returned instead
#   of the reference.
# notes:
#   A useful idiom is to use the => operator between parameters.  Thus you
#   may omit quotes around barewords (except for the rightmost one), and
#   it's also a nice visual representation of what you're asking for.
#   ALSO: if you have a top-level object in your config with only one
#   instance (like the "bot" object in the base config) then you may omit
#   the 0 as the second parameter.
# examples:
#   get('channel')              # hashref of channels, keyed on name
#   get(channel => '#perlbot')  # hashref of single channel's fields
#   get(channel => '#perlbot' => 'op')             # arrayref of ops
#   foreach (get(channel=>'#perlbot'=>'op')) {...}   # array context
#   get(bot => 'nick')          # omitting the 0
#   get(bot => 0 => 'nick')     # this works but the 0 isn't needed

sub get {
  my ($self, @keys) = @_;
  my ($current, $key, $ref, $level);

  # $current is a "pointer", iterated down the tree
  $current = $self->{_config};
  # $level keeps track of how far down the tree we are
  $level = 0;

  # loop over the list of keys we got
  while (defined ($key = shift @keys)) {
    # grab what kind of reference the current thing is
    $ref = ref($current);
    if ($ref eq 'ARRAY') {
      # check to see if $key is a non-integer (ints required for array indexing)
      if (int($key) ne $key) {
        # special case for singleton top-level objects, so the 0 index can be
        # omitted as the second parameter, e.g. this lets you write
        # get('bot','nick') instead of get('bot',0,'nick)
        if ($level == 1 and @$current == 1) {
          unshift(@keys, $key);
          $key = 0;
        } else {
          # otherwise, complain and return undef
          carp "non-integer key specified for array lookup ($key)";
          return undef;
        }
      }
      # "move pointer" down to next level
      $current = $current->[$key];
    } elsif ($ref eq 'HASH') {
      # no validity checks here; a hash key could be anything
      # "move pointer" down to next level
      $current = $current->{$key};
    } else {
      # if we get here, we've reached a "leaf" in the tree but there are
      # still more keys to deal with... that's bad.  complain and stop
      # iterating.  we will return the (scalar) value we've got here at
      # the leaf.
      carp "extra config keys specified (" . join(", ", $key, @keys), ")";
      last;
    }
    $level++;
  }

  # if the thing that was asked for is an array, and the call was in array
  # context, do the favor of dereferencing the array.  otherwise just return
  # the reference as is.
  if (ref($current) eq 'ARRAY' and wantarray) {
    return @$current;
  } else {
    return $current;
  }
}


sub set {
  my ($self) = @_;
}



1;
