#!/usr/bin/perl -w

# TITLE: - GPerlbotCFG
# AUTHOR: - Luke Petre  -  petre@jhu.edu

# Changes:

use Gtk;
use Gtk::Atoms;
use File::Basename;
use File::Spec;
use Perlbot;

use strict 'vars';

init Gtk;

# global variables
my $window;
my $fs_window;
my $spacing=5;
my $bwidth=10;
my $notebook;
my $current_object =undef;
my $current_class =undef;
my $current_config_file = '';
my $ob_list;
my $base_dir ='';
my $main_config_filename = 'config';
my $main_plugin_name = 'base';
my $current_plugin ='';
my $plugin_list;

my %meta;
my %config;
my %widget_data;
my $meta_other; 

if($^O =~ /mac/i) {
    $dirsep = ':';
} else {
    $dirsep = '/';
}

my %bool = 
    (
     1 => 'yes',
     0 => 'no'
     );

my @menu_entries = 
    (
     ["/_File",	undef,	0,	"<Branch>"],
     ["/File/tearoff1",	undef,	0,	"<Tearoff>"],
     ["/File/_New",	"<control>N",	1],
     ["/File/_Open",	"<control>O",	2],
     ["/File/sep1",	undef,	0,	"<Separator>"],
     ["/File/_Save Current Plugin", "<control>S",	3],
     ["/File/Save Current Plugin _As...",	"<control>A",	4],
     ["/File/sep1",	undef,	0,	"<Separator>"],
     ["/File/Save All _Plugins", "<control>P",	5],

     ["/File/sep1",	undef,	0,	"<Separator>"],
     {
	 'path' => "/File/_Quit", 
	 'accelerator' => "<control>Q",	
	 'action' => 6,
	 'type' => '<Item>'
	 },
     
     ["/_Help",	undef,	0,	"<LastBranch>"],
     ["/Help/_About",	undef,	30]
     );

my %menu_cbs = 
    ( 1 => \&file_new_cb,
      2 => \&file_open_cb,
      3 => \&file_save_cb,
      4 => \&file_save_as_cb,
      5 => \&file_save_all_cb,
      6 => \&file_quit_cb,
      30 => \&about_cb
      );

sub destroy_window {
    my($widget, $windowref, $w2) = @_;
    $$windowref = undef;
    $w2 = undef if defined $w2;
    0;
}

#  In order to add a widget type to gperlbotcfg you need to do the following
#    1.)  Add an unique key and coderef to each of the create, get, set, 
#         clear hashref's in the widget_ops hashref.  i.e. 
#
#      my $widget_ops = {
#          'create' => {
#	       'foo' => \&create_foo_widgets,
#               ...
#          'get' => {
#	       'foo' => \&get_foo_widgets,
#               ...
#          'set' => {
#	       'foo' => \&set_foo_widgets,
#               ...
#          'clear' => {
#	       'foo' => \&clear_foo_widgets,
#      }
#
#
#    2.)  Make sure there is a sub corresponding to each coderef you just 
#         added to the widget_ops hashref.
#
#    3.)  Make sure the subs that return data return the correct kind of data.
#         Create subs return any widget that can be packed, something to 
#         store into %widget_data so that the Set, Clear, and Get subs can 
#         access the pertinant widgets.
#
#         Get subs return arrayrefs with data to be stored into the config
#         struct
#
#    4.)  Just FYI, every sub gets passed parameters.
#         Set gets passed:
#            an array ref
#            and the widget(s) to set
#
#         Get gets passed
#            the widget(s) necessary to retrieve the data
#
#         Create gets passed
#            the index of the current field in the meta struct
#
#         Clear gets passed
#            the widget(s) to clear
#            the default value for that field if it exists, else undef
#
#     I hope that helps
#            


my $widget_ops = {
    'create' => {
	'boolean' => \&create_boolean_widgets,
	'string' => \&create_string_widgets,
	'directory' => \&create_directory_widgets,
	'pluginnoload' => \&create_pluginnoload_widgets,
	'int' => \&create_int_widgets,
	'flags' => \&create_flags_widgets,
	'stringlist' => \&create_stringlist_widgets,
	'objectlist' => \&create_objectlist_widgets,
     },

    'get' => {
	'boolean' => \&get_boolean_widgets,
	'string' => \&get_string_widgets,
	'directory' => \&get_directory_widgets,
	'pluginnoload' => \&get_pluginnoload_widgets,
	'int' => \&get_int_widgets,
	'flags' => \&get_flags_widgets,
	'stringlist' => \&get_stringlist_widgets,
	'objectlist' => \&get_objectlist_widgets,
	},

    'set' => {
	'boolean' => \&set_boolean_widgets,
	'string' => \&set_string_widgets,
	'directory' => \&set_directory_widgets,
	'pluginnoload' => \&set_pluginnoload_widgets,
	'int' => \&set_int_widgets,
	'flags' => \&set_flags_widgets,
	'stringlist' => \&set_stringlist_widgets,
	'objectlist' => \&set_objectlist_widgets,
     },

    'clear' => {
	'boolean' => \&clear_boolean_widgets,
	'string' => \&clear_string_widgets,
	'directory' => \&clear_directory_widgets,
	'pluginnoload' => \&clear_pluginnoload_widgets,
	'int' => \&clear_int_widgets,
	'flags' => \&clear_flags_widgets,
	'stringlist' => \&clear_stringlist_widgets,
	'objectlist' => \&clear_objectlist_widgets,
	}

};

#boolean widget_ops

sub create_boolean_widgets {
    my ($index) = @_;
    my (
	$checkbutton,
	$vbox,
	$init
	);

    $vbox = new Gtk::VBox 0, 10;

    if (exists $meta{$current_plugin}->{field}[$index]{default}) {
	$init = $meta{$current_plugin}->{field}[$index]{default}[0];
    }
    $checkbutton = new Gtk::CheckButton 
	$meta{$current_plugin}->{field}[$index]{display}[0];
    $checkbutton->can_focus(0);
    $checkbutton->set_active($init eq 'yes') if $init;

    show $checkbutton;

    $vbox->pack_start($checkbutton, 0, 0, 0);

    return ($vbox, $checkbutton);
}

sub get_boolean_widgets {
    my($widget) = @_;
    
    my $bool =  $widget->active;
    return ([$bool{$bool}]);
}

sub set_boolean_widgets {
    my( $array, $widget) = @_;
    $widget->set_active(@{$array}[0] eq 'yes');
}

sub clear_boolean_widgets {
    my($widget, $default) = @_;
}

# string widget_ops

sub create_string_widgets {
    my ($index) = @_;
    my (
	$entry,
	$frame,
	$hbox,
	$init,
	$maxlength
	);

    $frame = new Gtk::Frame
	$meta{$current_plugin}->{field}[$index]{display}[0];
    $frame->border_width( 0 );

    if (exists $meta{$current_plugin}->{field}[$index]{default}) {
	$init = $meta{$current_plugin}->{field}[$index]{default}[0];
    }

    if (exists $meta{$current_plugin}->{field}[$index]{maxlength}) {
	$maxlength = $meta{$current_plugin}->{field}[$index]{maxlength}[0];
    }

    $entry = new Gtk::Entry;
    $entry->set_max_length($maxlength) if $maxlength;
    $entry->set_text($init) if $init;
    $entry->show;	

    $hbox = new Gtk::HBox 0,0;
    $hbox->border_width($bwidth);

    $hbox->pack_start_defaults($entry);
    
    $frame->add($hbox);

    return ($frame, $entry);
}

sub get_string_widgets{
    my($widget) = @_;
    
    my $string = $widget->get_text;
    
    return ([$string]);
}

sub set_string_widgets{
    my( $array, $widget) = @_;
    $widget->set_text(@{$array}[0]);
}

sub clear_string_widgets{
    my($widget, $default) = @_;
    $widget->set_text('');
}

# int widget_ops

sub create_int_widgets {
    my ($index) = @_;
    my (
	$vbox,
	$frame,
	$adj,
	$spinner,
	$min,
	$max,
	$init
    );
    $vbox = new Gtk::VBox 0, 10;   
    $vbox->border_width($bwidth);

    $frame = new Gtk::Frame
	$meta{$current_plugin}->{field}[$index]{display}[0];
    $frame->border_width( 0 );

    if (exists $meta{$current_plugin}->{field}[$index]{min}) {
	$min = $meta{$current_plugin}->{field}[$index]{min}[0];
    }

    if (exists $meta{$current_plugin}->{field}[$index]{max}) {
	$max = $meta{$current_plugin}->{field}[$index]{max}[0];
    }

    if (exists $meta{$current_plugin}->{field}[$index]{default}) {
	$init = $meta{$current_plugin}->{field}[$index]{default}[0];
    }

    defined $min or $min = -2**31;
    defined $max or $max = 2**31;
    
    if (defined $init ) {
	$init = $min < 0 ? 0 : $min;
	$init = $max > 0 ? $init : $max;
    }

    $adj = new Gtk::Adjustment $init, $min, $max, 1.0, 5.0, 0.0;
    
    $spinner = new Gtk::SpinButton $adj, 0, 0;
    $spinner->set_wrap(0);

    $vbox->pack_start($spinner, 0, 1, 0);
    $frame->add($vbox);

    return ($frame, $spinner);
}

sub get_int_widgets{
    my($widget) = @_;

    my $int = $widget->get_value_as_int;

    return ([$int]);
}

sub set_int_widgets{
    my( $array, $widget) = @_;
    $widget->set_value(@{$array}[0]);
}

sub clear_int_widgets{
    my($widget, $default) = @_;
    $widget->set_value($default) if defined $default;
}

# flags widget_ops

sub create_flags_widgets {
    my ($index) = @_;
    my (
	$vbox,
	$vbox2,
	$scroller,
	$frame,
	$checkbutton,
	@displays,
	@values,
	$store,
	$init
    );
    $vbox = new Gtk::VBox 0, 0;   

    @displays = split /:/, $meta{$current_plugin}->{field}[$index]{flagnames}[0];
    @values = split /:/,  $meta{$current_plugin}->{field}[$index]{flags}[0];

    $frame = new Gtk::Frame
	$meta{$current_plugin}->{field}[$index]{display}[0];
    $frame->border_width( 0 );

    $scroller = new Gtk::ScrolledWindow(undef, undef);
    $scroller->border_width( $bwidth );
    $scroller->set_policy(-automatic, -automatic);
    $scroller->show;

    my $eye=0;
    foreach (@displays) {
	$checkbutton = new Gtk::CheckButton $_;
	$checkbutton->can_focus(0);

	show $checkbutton;
	
	$store->{$values[$eye]}=$checkbutton;

	$vbox->pack_start($checkbutton, 0, 0, 0);

	$eye++;
    }

    $scroller->add_with_viewport($vbox);

    $frame->add($scroller);
    return ($frame, $store);
}

sub get_flags_widgets{
    my($widget) = @_;
    my @array;
    my $bool;

    foreach (keys %{$widget}) {
	$bool = $widget->{$_}->active;
	push @array, $_ if $bool;
    }

    return (\@array);
}

sub set_flags_widgets{
    my( $array, $widget) = @_;

    foreach (@{$array}) {
	$widget->{$_}->set_active(1);
    }
}

sub clear_flags_widgets{
    my($widget, $default) = @_;

    foreach (keys %{$widget}) {
	$widget->{$_}->set_active(0);
    }
}

# stringlist widget_ops

sub create_stringlist_widgets {
    my ($index) = @_;
    my (
	$vbox,
	$hbox,
	$frame,
	$scroller,
	$list,
	$list_item,
	$entry,
	$button,
	$init,
	$l_sel

    );
    $vbox = new Gtk::VBox 0, 10;
    $vbox->border_width($bwidth);
    $hbox = new Gtk::HBox 0, 10;   

    $frame = new Gtk::Frame
	$meta{$current_plugin}->{field}[$index]{display}[0];
    $frame->border_width( 0 );

    $entry = new Gtk::Entry;

    $scroller = new Gtk::ScrolledWindow(undef, undef);
    $scroller->set_policy(-automatic, -automatic);
    $scroller->show;

    $list = new Gtk::List;
    $list->signal_connect("select_child" => sub { 
	$l_sel=$_[1]; });
	
    $list->set_selection_mode(-single);
    $scroller->add_with_viewport($list);

    $button = new Gtk::Button "add";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 	
	if ($entry->get_text ne ''){
	    $list_item = new Gtk::ListItem(	$entry->get_text);
	    $list_item->{text} = $entry->get_text;
	    $entry->set_text('');
	    $list->add($list_item);
	    $list_item->show;
	}
    });
    $button->show;

    $hbox->pack_start($button, 0, 0, 0);
    $hbox->pack_start($entry, 0, 0, 0);
    
    $button = new Gtk::Button "remove";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
	$list->remove($l_sel)if defined $l_sel; 
	$l_sel=undef; });
    $button->show;

    $hbox->pack_end($button, 0, 0, 0);

    $vbox->pack_start($scroller, 0, 1, 0);
    $vbox->pack_start($hbox, 0, 1, 0);

    $frame->add($vbox);

    return ($frame, $list);
}

sub get_stringlist_widgets{
    my($widget) = @_;
    
    my @array;
    my $string;
    foreach my $item ($widget->children){
	$string = $item->{text};
	push @array, $string;
    }    
    return (\@array);

}

sub set_stringlist_widgets{
    my( $array, $widget) = @_;
    my $list_item;
    $widget->clear_items(0, -1);

    foreach (@{$array}) {
	$list_item = new Gtk::ListItem($_);
	$list_item->{text} = $_;
	$widget->add($list_item);
	$list_item->show;
    }
}

sub clear_stringlist_widgets{
    my($widget, $default) = @_;
    $widget->clear_items(0, -1);
}

# directory widgets, 19990126 - LWP needs work

sub create_directory_widgets {
    my ($index) = @_;
    my (
	$entry,
	$button,
	$frame,
	$hbox,
	$init,
	$maxlength
	);

    $frame = new Gtk::Frame
	$meta{$current_plugin}->{field}[$index]{display}[0];
    $frame->border_width( 0 );

    if (exists $meta{$current_plugin}->{field}[$index]{default}) {
	$init = $meta{$current_plugin}->{field}[$index]{default}[0];
    }

    if (exists $meta{$current_plugin}->{field}[$index]{maxlength}) {
	$maxlength = $meta{$current_plugin}->{field}[$index]{maxlength}[0];
    }

    $entry = new Gtk::Entry;
    $entry->set_max_length($maxlength) if $maxlength;
    $entry->set_text($init) if $init;
    $entry->show;	

    $button = new Gtk::Button "Browse";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub {     
	if (not defined $fs_window) {
	    $fs_window = new Gtk::FileSelection "Select a Directory";
	    $fs_window->position(-mouse);
	    $fs_window->signal_connect("destroy", \&destroy_window, \$fs_window);
	    $fs_window->signal_connect("delete_event", \&destroy_window, \$fs_window);
	    $fs_window->ok_button->signal_connect("clicked" , sub {
		my $filename = $fs_window->get_filename;
		$filename = dirname($filename) if -f $filename;
		$entry->set_text($filename);
		destroy $fs_window; 
	    });
	    $fs_window->
		cancel_button->
		    signal_connect("clicked", sub { destroy $fs_window });
	}
	if (!visible $fs_window) {
	    show $fs_window;
	} else {
	    destroy $fs_window;
	}
    });
    $button->show;

    $entry->set_text($init) if $init;

    $entry->show;	

    $hbox = new Gtk::HBox 0,10;
    $hbox->border_width($bwidth);

    $hbox->pack_start($entry, 1, 1, 0);
    $hbox->pack_end_defaults($button);
    
    $frame->add($hbox);

    return ($frame, $entry);
}

sub get_directory_widgets{
    my($widget) = @_;
    
    my $string = $widget->get_text;
    
    return ([$string]);
}

sub set_directory_widgets{
    my( $array, $widget) = @_;
    $widget->set_text(@{$array}[0]);
}

sub clear_directory_widgets{
    my($widget, $default) = @_;
    $widget->set_text('');
}

# objectlist widget_ops

sub create_objectlist_widgets {
    my ($index) = @_;
    my (
	$vbox,
	$hbox,
	$list,
	$list_all,
	$list_item,
	$frame,
	$scroller,
	$button,
	$init,
	$plugin,
	$class,
	$la_sel,
	$l_sel,
	@temp
    );
    $vbox = new Gtk::VBox 0, 10;   
    $vbox->border_width($bwidth);

    $hbox = new Gtk::HBox 1, 10;   
    $hbox->border_width($bwidth);

    $plugin = $meta{$current_plugin}->{field}[$index]{objectplugin}[0];
    $class = $meta{$current_plugin}->{field}[$index]{objectclass}[0];

    $frame = new Gtk::Frame
	$meta{$current_plugin}->{field}[$index]{display}[0];
    $frame->border_width( 0 );

    $scroller = new Gtk::ScrolledWindow(undef, undef);
    $scroller->set_usize(6, 100);    
    $scroller->set_policy(-automatic, -automatic);
    $scroller->show;

    $list_all = new Gtk::List;
    $list_all->signal_connect("select_child" => sub { 
	$la_sel=$_[1]; });
    $list_all->set_selection_mode(-single);
    $scroller->add_with_viewport($list_all);

    foreach (@{$config{$plugin}->{$class}}) 
    {
	$list_item = new Gtk::ListItem($_->{name}[0]);
	$list_item->{text} = $_->{name}[0];
	$list_all->add($list_item);
	$list_item->show;
    }

    $list = new Gtk::List;
    $list->signal_connect("select_child" => sub { 
	$l_sel=$_[1]; });
    $list->set_selection_mode(-single);

    $hbox->pack_start($scroller, 1,1,0);

    $button = new Gtk::Button "add ->";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
	$list_all->remove($la_sel)if defined $la_sel; 
	$list->add($la_sel) if defined $la_sel; 
	$la_sel=undef; });
    $button->show;

    $vbox->pack_start($button, 1,1,0);
    $button = new Gtk::Button "add all ->";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
	foreach ($list_all->children){
	    $list_all->remove($_);
	    $list->add($_);
	} });
   	
    $button->show;

    $vbox->pack_start($button, 1,1,0);

    $button = new Gtk::Button "<- remove all";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
	foreach ($list->children){
	    $list->remove($_);
	    $list_all->add($_);
	} });
    $button->show;

    $vbox->pack_start($button, 1,1,0);

    $button = new Gtk::Button "<- remove";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
	$list->remove($l_sel)if defined $l_sel; 
	$list_all->add($l_sel) if defined $l_sel; 
	$l_sel=undef; });
    $button->show;

    $vbox->pack_start($button, 1,1,0);

    $hbox->pack_start($vbox, 0,0,0);

    $scroller = new Gtk::ScrolledWindow(undef, undef);
    $scroller->set_policy(-automatic, -automatic);
    $scroller->show;

    $scroller->add_with_viewport($list);

    $hbox->pack_start($scroller, 1,1,0);

    $frame->add($hbox);
    @temp = ($list, $list_all);

    return ($frame, \@temp);
}

sub get_objectlist_widgets{
    my($widget) = @_;
    
    my @array;

    foreach (@{$widget}[0]->children){
	push @array, $_->{text};
    }    
    return (\@array);
}

sub set_objectlist_widgets{
    my( $array, $widget) = @_;
    my $list_item;

    foreach my $item (@{$widget}[0]->children){
	@{$widget}[0]->remove($item);
	@{$widget}[1]->add($item);
    }
    foreach (@{$array}) {
	$list_item = new Gtk::ListItem($_);
	$list_item->{text} = $_;
	@{$widget}[0]->add($list_item);
	$list_item->show;
	foreach my $item(@{$widget}[1]->children){
	    @{$widget}[1]->remove($item) if $item->{text} eq $_;
	}
    
    }
}

sub clear_objectlist_widgets{
    my($widget, $default) = @_;

    foreach my $item (@{$widget}[0]->children){
	@{$widget}[0]->remove($item);
	@{$widget}[1]->add($item);
    }
}

# pluginnoload widget_ops

sub create_pluginnoload_widgets {
    my ($index) = @_;
    my (
	$vbox,
	$hbox,
	$list,
	$list_all,
	$list_item,
	$frame,
	$scroller,
	$button,
	$init,
	$la_sel,
	$l_sel,
    );
    $vbox = new Gtk::VBox 0, 10;   
    $vbox->border_width($bwidth);

    $hbox = new Gtk::HBox 1, 10;   
    $hbox->border_width($bwidth);

    $frame = new Gtk::Frame
	$meta{$current_plugin}->{field}[$index]{display}[0];
    $frame->border_width( 0 );

    $scroller = new Gtk::ScrolledWindow(undef, undef);
    $scroller->set_usize(6, 100);    
    $scroller->set_policy(-automatic, -automatic);
    $scroller->show;

    $list_all = new Gtk::List;
    $list_all->signal_connect("select_child" => sub { 
	$la_sel=$_[1]; });
    $list_all->set_selection_mode(-single);
    $scroller->add_with_viewport($list_all);

    foreach ($plugin_list->children) 
    {
	if ($_->{plugin} ne $main_plugin_name){
	    $list_item = new Gtk::ListItem($_->{plugin});
	    $list_item->{text} = $_->{plugin};
	    $list_all->add($list_item);
	    $list_item->show;
	}
    }

    $list = new Gtk::List;
    $list->signal_connect("select_child" => sub { 
	$l_sel=$_[1]; });
    $list->set_selection_mode(-single);

    $hbox->pack_start($scroller, 1,1,0);

    $button = new Gtk::Button "disable ->";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
	$list_all->remove($la_sel)if defined $la_sel; 
	$list->add($la_sel) if defined $la_sel; 
	$la_sel=undef; });
    $button->show;

    $vbox->pack_start($button, 1,1,0);

    $button = new Gtk::Button "disable all ->";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
	foreach ($list_all->children){
	    $list_all->remove($_);
	    $list->add($_);
	} });
    $button->show;

    $vbox->pack_start($button, 1,1,0);

    $button = new Gtk::Button "<- enable all";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
	foreach ($list->children){
	    $list->remove($_);
	    $list_all->add($_);
	} });
    $button->show;

    $vbox->pack_start($button, 1,1,0);

    $button = new Gtk::Button "<- enable";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
	$list->remove($l_sel)if defined $l_sel; 
	$list_all->add($l_sel) if defined $l_sel; 
	$l_sel=undef; });
    $button->show;

    $vbox->pack_start($button, 1,1,0);

    $hbox->pack_start($vbox, 0,0,0);

    $scroller = new Gtk::ScrolledWindow(undef, undef);
    $scroller->set_policy(-automatic, -automatic);
    $scroller->show;

    $scroller->add_with_viewport($list);

    $hbox->pack_start($scroller, 1,1,0);

    $frame->add($hbox);

    return ($frame, [$list, $list_all]);
}

sub get_pluginnoload_widgets{
    my($widget) = @_;
    
    my @array;

    foreach (@{$widget}[0]->children){
	push @array, $_->{text};
    }    
    return (\@array);
}

sub set_pluginnoload_widgets{
    my( $array, $widget) = @_;
    my $list_item;

    foreach my $item (@{$widget}[0]->children){
	@{$widget}[0]->remove($item);
	@{$widget}[1]->add($item);
    }
    foreach (@{$array}) {
	$list_item = new Gtk::ListItem($_);
	$list_item->{text} = $_;
	@{$widget}[0]->add($list_item);
	$list_item->show;
	foreach my $item(@{$widget}[1]->children){
	    @{$widget}[1]->remove($item) if $item->{text} eq $_;
	}
    
    }
}

sub clear_pluginnoload_widgets{
    my($widget, $default) = @_;

    foreach my $item (@{$widget}[0]->children){
	@{$widget}[0]->remove($item);
	@{$widget}[1]->add($item);
    }
}

sub add_multi {
    my (
	$hbox,
	$vbox,
	$vbox2,
	$list,
	$list_item,
	$scroller,
	$old_index,
	$button
	); 
    my $class = shift;

    $hbox = new Gtk::HBox 0, 10;   
    $vbox = new Gtk::VBox 0, 10;   
    $vbox2 = new Gtk::VBox 0, 10;   

    $scroller = new Gtk::ScrolledWindow(undef, undef);
    $scroller->set_policy(-automatic, -automatic);
    $scroller->show;

    $list = new Gtk::List;
    $list->signal_connect("select_child" => sub { 
        object_select($_[1],$old_index, $list); 
	$old_index = $_[1]->{index};
    });
	
    $list->set_selection_mode(-single);
    $scroller->add_with_viewport($list);
    
    $button = new Gtk::Button "add";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
        object_add($list); });
    $hbox->pack_start($button, 0, 1, 0);
    $button->show;
    
    $button = new Gtk::Button "remove";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
        object_remove($list); 
	$old_index = undef;
    });
    $hbox->pack_start($button, 0, 1, 0);
    $button->show;
    $vbox2->pack_start($hbox,0,1,0);

    $button = new Gtk::Button "remove all";
    $button->can_focus(0);
    $button->signal_connect("clicked" => sub { 
        object_remove_all($list); 
	$old_index = undef;
    });
    $vbox2->pack_start($button, 0, 1, 0);
    $button->show;

    $vbox->pack_start($scroller, 1,1,0);
    show $list;
    $ob_list->{$class} = $list;
    $vbox->pack_start($vbox2, 0, 0, 0);
    my $eye=0;
    foreach (@{$config{$current_plugin}->{$class}}) {
	$list_item = new Gtk::ListItem($_->{name}[0]);
	$list_item->{name} = $_->{name}[0];
	$list_item->{class} = $class;
	$list_item->{index} = $eye;
	$list->add($list_item);
	$list_item->show;
	$eye++;
    }
    return $vbox;
}

sub object_select {
   my( $obj, $old_index, $list) = @_;

   my $index = $obj->{index};
   $current_object = $obj;

   defined $old_index or $old_index = $index;

   #if switching objects
   if ($index != $old_index) {
       object_unselect($old_index, $list);
   }


   foreach my $key(%{$config{$current_plugin}->{$current_class}[$index]}){
       foreach (@{$meta{$current_plugin}->{field}}) {

	   if((lc($_->{class}[0]) eq lc($current_class)) 
	      and (lc($_->{name}[0]) eq lc($key))) {
	       &{$widget_ops->{'set'}{$_->{type}[0]}}(\@{$config
					   {$current_plugin}->
					   {$current_class}[$index]->
					   {$_->{name}[0]}},
					   $widget_data{$current_class}{$_->{name}[0]});	
	   }

       }
       
   }
}

sub object_unselect {
    my ($index) = @_;

    object_write($current_class, $index);
    
    foreach my $field(@{$meta{$current_plugin}->{field}}) {
	if(lc($field->{class}[0]) eq lc($current_class)) { 
	    &{$widget_ops->{'clear'}{$field->{type}[0]}}($widget_data{$current_class}{$field->{name}[0]},
						    $field->{default}[0] );
	}
    }
}

sub object_write {
    my ($class,$index) = @_;
    my $data;


    #loop through the meta structure, and for each field in this class
    #get the widget value and insert it into the config struct

    #if you change the name of the object, then you have to update the list
    #or else that would be bad

    my $obj = $config{$current_plugin}->{$class}[$index];
    
    foreach my $field(@{$meta{$current_plugin}->{field}}) {
	if(lc($field->{class}[0]) eq lc($class)) {
	    $data->{$field->{name}[0]} = 
		&{$widget_ops->{'get'}
		  {$field->{type}[0]}}($widget_data{$class}{$field->{name}[0]});
	    
	    if((lc($field->{name}[0]) eq lc('name')) 
	       and (lc($data->{name}[0]) ne
		    lc($obj->{name}[0]))) {
		
		my $list_item = new Gtk::ListItem($data->{name}[0]);
		$list_item->{name} = $data->{name}[0];
		$list_item->{class} = $class;
		$list_item->{index} = $index;
		$ob_list->{$class}->insert_items($index,$list_item);
		$list_item->show;
		foreach my $item($ob_list->{$class}->children){
		    $ob_list->{$class}->remove($item) 
			if $item->{name} eq 
			    $config{$current_plugin}->{$class}[$index]{$field->{name}[0]}[0];
		}
	    }
	}
    }
    $config{$current_plugin}->{$class}[$index] = $data;
}

sub current_object_write {
    if (defined $current_object){
	object_write($current_class, $current_object->{index});
    }
}

sub object_add {
   my($list) = @_;
   my (
       $new_obj,
       $list_item,
       );

   foreach (@{$meta{$current_plugin}->{field}}) { 
       if ((lc($_->{class}[0]) eq lc($current_class)))  {
	   if (lc($_->{name}[0]) eq 'name') {
	       $new_obj->{$_->{name}[0]}=[$current_class];
	   }
	   $new_obj->{$_->{name}[0]}=$_->{default} if defined $_->{default}[0];
       }
   }
   push @{$config{$current_plugin}->{$current_class}}, $new_obj;
   $list_item = new Gtk::ListItem($new_obj->{name}[0]);
   $list_item->{name} = $new_obj->{name}[0];
   $list_item->{class} = $current_class;
   $list_item->{index} = @{$config{$current_plugin}->{$current_class}} -1 ;
   $list->add($list_item);
   $list_item->show;
   $list->select_child($list_item);
}

sub object_remove {
   my($list) = @_;


   if ($current_object){
       my $index = $current_object->{index};
       $current_object = undef;
       $list -> clear_items(0, -1);
       foreach (@{$meta{$current_plugin}->{field}}) { 
	   if ((lc($_->{class}[0]) eq lc($current_class)))  {

	       my $default = $_{default}[0] if exists $_{default};

	       &{$widget_ops->{'clear'}{$_->{type}[0]}}($widget_data{$current_class}
							{$_->{name}[0]},$default );
	   }
       }

       splice @{$config{$current_plugin}->{$current_class}}, $index, 1;
       my $eye=0;
       my $list_item;
       foreach (@{$config{$current_plugin}->{$current_class}}) {
	   $list_item = new Gtk::ListItem($_->{name}[0]);
	   $list_item->{name} = $_->{name}[0];
	   $list_item->{class} = $current_class;
	   $list_item->{index} = $eye;
	   $list->add($list_item);
	   $list_item->show;
	   $eye++;
       }
   }
}

sub object_remove_all {
   my($list) = @_;
   $config{$current_plugin}->{$current_class} = [];
   foreach (@{$meta{$current_plugin}->{field}}) { 
       if ((lc($_->{class}[0]) eq lc($current_class)))  {
	   my $default = $_{default}[0] if exists $_{default};
	   
	   &{$widget_ops->{'clear'}{$_->{type}[0]}}($widget_data{$current_class}
						    {$_->{name}[0]},$default );
       }
   }
   $list->clear_items(0, -1);
}

sub notebook_page_switch {
	my( $widget, $new_page, $page_num) = @_;

	current_object_write;
	$current_object = undef;
	$current_class = $new_page->{child}{class};
}

sub notebook_create_pages {
    my(
       $child,
       $label,
       $page,
       $entry,
       $frame,
       $frame_box,
       $vbox,
       $hbox,
       $hseparator,
       $vseparator,
       $label_box,
       $menu_box,
       $button,
       $buffer,
       $multi,
       $scroller,
       $temp,
       $obj,
       @stuff
       );

    $page = $notebook->get_current_page;
    while($page >= 0 ){
	$notebook->remove_page($page);
	$page = $notebook->get_current_page;
    }


    foreach my $class (@{$meta{$current_plugin}->{class}}) {
	$child = new Gtk::Frame;
	$child->border_width( 5 );

	$hbox = new Gtk::HBox( 0, 5 );
	$hbox->border_width( 5 );
	$child->add( $hbox );

	$vbox = new Gtk::VBox( 0, 5 );
	$vbox->border_width( 10 );

	$scroller = new Gtk::ScrolledWindow(undef, undef);
	$scroller->set_policy(-automatic, -automatic);
	$scroller->show;
	$scroller->add_with_viewport($vbox);

	if( $class->{single}[0] ne 'yes') {
	    $label =new Gtk::Label( 'multi' );
	    $multi = add_multi($class->{name}[0]);
	    $hbox->pack_start( $multi, 0, 0, 0 );
	    $vseparator = new Gtk::VSeparator;
	    $hbox->pack_start( $vseparator, 0, 0, 0 );
	}
	$hbox->pack_start( $scroller, 1, 1, 0 );
	my $eye=0;
	foreach(@{$meta{$current_plugin}->{field}}){
	    if(lc($_->{class}[0]) eq lc($class->{name}[0])){
		if (lc($_->{type}[0]) ne 'boolean'){
		    
		    @stuff = &{$widget_ops->{'create'}{$_->{type}[0]}}($eye);
		    $vbox->pack_start( $stuff[0], 0, 0, 0 );
		    
		    #store it in %widget_data
		    $widget_data{$_->{class}[0]}{$_->{name}[0]} = $stuff[1];
		}
	    }
	    $eye++;
	}

	$frame = new Gtk::Frame ('Other Options');
	$frame_box = new Gtk::VBox (0, 0);
	$frame_box->border_width($bwidth);
	$frame->add($frame_box);
	

	$eye=0;
	my $exist_bool = 0;
	foreach(@{$meta{$current_plugin}->{field}}){
	    if(lc($_->{class}[0]) eq lc($class->{name}[0])){
		if (lc($_->{type}[0]) eq 'boolean'){
		    if($exist_bool == 0) {
			$exist_bool = 1;
			$vbox->pack_start( $frame, 0, 0, 0 );
		    }
		    @stuff = &{$widget_ops->{'create'}{$_->{type}[0]}}($eye);
		    $frame_box->pack_start( $stuff[0], 0, 0, 0 );
		    
		    #store it in %widget_data
		    $widget_data{$_->{class}[0]}{$_->{name}[0]} = $stuff[1];
		}
	    }
	    $eye++;
	}

	$child->show_all();
	$child->{class}=$class->{name}[0];
	
	$label_box = new Gtk::HBox 0, 0;
	$label = new Gtk::Label $class->{display}[0];
	$label_box->pack_start($label, 0, 1, 0);
	show_all $label_box;
    
	$menu_box = new Gtk::HBox( 0, 0 );
	$label = new Gtk::Label($class->{display}[0]);
	$menu_box->pack_start( $label, 0, 1, 0 );
	$menu_box->show_all();
	
	$notebook->append_page_menu($child, $label_box, $menu_box);
	if ($class->{single}[0] eq 'yes'){
	    $obj = new Gtk::ListItem('la');
	    $obj->{name} = 'la';
	    $obj->{class} =$class->{name}[0];
	    $obj->{index} =0;
	    object_select($obj,0, undef)
	    }
    }
}

sub menu_cb {
    my ($widget, $action, @data) = @_;
    
    &{$menu_cbs{$action}};
    
}

sub file_new_cb {
    if (not defined $fs_window) {
	$fs_window = new Gtk::FileSelection "file selection dialog";
	$fs_window->position(-mouse);
	$fs_window->signal_connect("destroy", \&destroy_window, \$fs_window);
	$fs_window->signal_connect("delete_event", \&destroy_window, \$fs_window);
	$fs_window->ok_button->signal_connect("clicked" , sub {
	    $current_object =undef;
	    $current_class =undef;
	    $current_config_file = '';
	    $current_plugin ='';

	    $ob_list = undef;
	    %meta = undef;
	    %config = undef;

	    $plugin_list->clear_items(0, -1);
	    my $filename = $fs_window->get_filename;
	    destroy $fs_window; 
	    new_config($filename);

	});
	$fs_window->cancel_button->signal_connect("clicked", sub { destroy $fs_window });
    }
    if (!visible $fs_window) {
	show $fs_window;
    } else {
	destroy $fs_window;
    }
}

sub file_open_cb {
    if (not defined $fs_window) {
	$fs_window = new Gtk::FileSelection "file selection dialog";
	$fs_window->position(-mouse);
	$fs_window->signal_connect("destroy", \&destroy_window, \$fs_window);
	$fs_window->signal_connect("delete_event", \&destroy_window, \$fs_window);
	$fs_window->ok_button->signal_connect("clicked" , sub {
	    my $filename = $fs_window->get_filename;
	    destroy $fs_window; 

	    load_config($filename, 1);
	});
	$fs_window->cancel_button->signal_connect("clicked", sub { destroy $fs_window });
    }
    if (!visible $fs_window) {
	show $fs_window;
    } else {
	destroy $fs_window;
    }
}

sub file_save_cb {
    current_object_write;
    write_plugin($current_plugin);
    $window->set_title("GPerlbotCFG : ".$main_config_filename);
}

sub file_save_as_cb {
    my $save_as_window;
    $save_as_window = new Gtk::FileSelection "file selection dialog";
    $save_as_window->position(-mouse);
    $save_as_window->signal_connect("destroy", 
				    \&destroy_window, \$save_as_window);
    $save_as_window->signal_connect("delete_event", 
				    \&destroy_window, \$save_as_window);
    $save_as_window->ok_button->signal_connect("clicked" , sub {
	my ($name, $type);
	($name, $base_dir, $type) = 
	    fileparse($save_as_window->get_filename,'');
	$main_config_filename = $name.$type;
	file_save_cb;
	destroy $save_as_window; 
    });
    $save_as_window->
	cancel_button->signal_connect("clicked", 
				      sub { destroy $save_as_window });
    if (!visible $save_as_window) {
	show $save_as_window;
    } else {
	destroy $save_as_window;
    }
}

sub file_save_all_cb {
    current_object_write;
    foreach ($plugin_list->children) 
    {
	write_plugin($_->{plugin});
    }
}

sub write_plugin {
    my ($pluginname) = @_;

    $current_config_file = $base_dir . $dirsep . $main_config_filename;
    if ($pluginname ne $main_plugin_name){
	$current_config_file = $plugindir . $dirsep . $pluginname . $dirsep . 'config';
    }
    write_config($current_config_file, $config{$pluginname});
}

sub file_quit_cb {
  $window->destroy();
}

sub about_cb {
  	    my $vbox = new Gtk::VBox 0, 0;
	    $vbox->border_width($bwidth);

	    my $label = new Gtk::Label
		('GPerlbotCFG created by Luke Petre <petre@jhu.edu>
		  with assistance from Jeremy Muhlich, 
                  and Andrew Burke (creators of perlbot)
		  check out http://perlbot.sourceforge.net/ for 
                  the latest version of perlbot and GPerlbotCFG');
	    $vbox->pack_start($label, 0, 1, 0);
	    $label->show;

	    create_dialog($vbox, 1, 0, 'About GPerlbotCFG');
}

sub plugin_add {
    my ($name, $display, $prepend) = @_;

    my (
	$list_item,
	);

    $list_item = new Gtk::ListItem($display);
    $list_item->{plugin} = $name;
    $plugin_list->prepend_items($list_item) if $prepend;
    $plugin_list->append_items($list_item) if !$prepend;
    $list_item->show;
    $plugin_list->select_child($list_item);
}

sub load_plugins {
    my ($dir) = @_;
    my $metafile;
    $plugindir = $dir;

    opendir(PDH, $dir);
    DIR: foreach (readdir(PDH)) {
        # ignore '.' and '..' silently
        if (/\.\.?/) {
            next DIR;
        }
        validate_plugin($_) or next DIR;
	if( -f $dir . $dirsep . $_ . $dirsep . 'meta') {
	    read_meta(	$dir . $dirsep . $_ . $dirsep . 'meta',	$_);
	}
	if( -f $dir . $dirsep . $_ . $dirsep . 'config') {
	    $config{$_} = parse_config($dir . $dirsep . $_ . $dirsep . 'config');
	}
	plugin_add($_, $_, 0);
    }
    closedir(PDH);

    #redistribute meta_other
    foreach my $key(keys %{$meta_other}){
	foreach (@{$meta_other->{$key}}){
	    push @{$meta{$_->{plugin}[0]}{$key}}, $_;
	}
    }
}



sub plugin_select {
    if ($current_plugin ne $_[0]) {
	#update config structure
	current_object_write;
	$current_plugin = $_[0];
	notebook_create_pages;
	#load in data from config structure
    } 
}

sub read_meta {
    my ($filename, $plugin) = @_;
    my $meta = parse_config($filename);
    
    for (my $i=0; $i < @{$meta->{field}}; $i++) {
	if (lc($meta->{field}[$i]{plugin}[0]) ne lc($plugin)) {
	    push @{$meta_other->{field}}, splice(@{$meta->{field}}, $i, 1);
	    $i--;
	}
	
    }
    for (my $i=0; $i < @{$meta->{class}}; $i++) {
	if (lc($meta->{class}[$i]{plugin}[0]) ne lc($plugin)) {
	    push @{$meta_other->{class}}, splice(@{$meta->{class}}, $i, 1);
	    $i--;
	}
	
    }
    
    $meta{$plugin}= 
    {
	field=>$meta->{field},
	class=>$meta->{class}
    };
    
}

sub load_config {
    my ($new_config, $flag) = @_;
    
    return 0 if !defined $new_config;

    if ((! -f $new_config)
	or (lc(ref(parse_config($new_config))) ne 'hash')){

	return 2 if $flag == 2;

	my $vbox = new Gtk::VBox 0, 0;
	$vbox->border_width($bwidth);
	    
	my $label = new 
	  Gtk::Label('The specified file is not a valid config file,');
	$vbox->pack_start($label, 0, 1, 0);
	$label->show;

	$label = new 
	  Gtk::Label('please try again,');
	$vbox->pack_start($label, 0, 1, 0);
	$label->show;

	create_dialog($vbox, 0, $flag, 'Bad Config File');

	return 0;
    }


    $current_config_file = $new_config;
    $config{$main_plugin_name} = parse_config($current_config_file);
    $plugin_list->clear_items(0, -1);
    $current_plugin = '';

    my $temp = dirname($new_config);
    my $new_meta = File::Spec->catfile(dirname($new_config), 'meta');
    if( -f $new_meta) {
	read_meta($new_meta, $main_plugin_name);
    }else {
	create_meta_from_config($main_plugin_name);
    }

    if (exists $config{$main_plugin_name}->{bot}) {
	if (exists $config{$main_plugin_name}->{bot}[0]{plugindir}) {
	    load_plugins($config{$main_plugin_name}->{bot}[0]{plugindir}[0]);
	}
    }

    plugin_add($main_plugin_name,'Main Config Settings', 1); 
    my ($name, $type);
    ($name, $base_dir, $type) = fileparse($new_config,'');
    $main_config_filename = $name.$type;
   
    $window->set_title("GPerlbotCFG : ".$main_config_filename);

    return 1;

}

sub new_config {
    $current_config_file = shift; 
    my $new_meta = 'meta';
    return if ! -f $new_meta;
    read_meta($new_meta, $main_plugin_name);
    plugin_add($main_plugin_name,'Main Config Settings');
}

sub check_for_files {
    #check for command line config file specfication   
    my $test = load_config($ARGV[0],2);
    return 0 if $test == 1;
    
    #else check for config file in current dir
    if (-f $main_config_filename){
	return $test if load_config($main_config_filename,0);
    }
    #else start with new_config
    new_config($main_config_filename);
    return $test;
}

sub create_meta_from_config {
    my ($plugin) = @_;
    my (
	$class,
	$field
	);

    foreach my $key (keys(%{$config{$plugin}})) {
	my (
	    $new_class,
	    $found_fields
	    );

	$new_class->{display} = [$key];
	$new_class->{name} = [$key];
	$new_class->{plugin} = [$plugin];
	$new_class->{single} = ['yes'];

	if (defined $config{$plugin}->{$key}[1]){
	    $new_class->{single} = ['no'];
	}

	my $eye = 0;
	foreach (@{$config{$plugin}->{$key}}) {
	    foreach my $name(keys(%{$config{$plugin}->{$key}[$eye]})) {	    
		my $new_field;
		
		$new_field->{plugin} = [$plugin];
		$new_field->{class} = [$key];
		$new_field->{name} = [$name];
		$new_field->{display} = [$name];
		$new_field->{type} = ['stringlist'];
		
		if (!exists $found_fields->{$name}) {
		    $found_fields->{$name}= 1;
		    push @{$field}, $new_field;
		}

	    }
	    $eye++;
	}
	
	push @{$class}, $new_class;
    }
    
    
    $meta{$plugin} =
    {
	class=>$class,
	field=>$field
	};
    
}
sub create_dialog {
    my ($widget, $modal, $flag, $title) = @_;

    my $dialog = new Gtk::Dialog;
    $dialog->position(-mouse);
    $dialog->set_modal($modal);
    $dialog->signal_connect("destroy", \&file_open_cb) if $flag == 1;
    $dialog->set_title($title);
	    
    $widget->show;
	    
    $dialog->vbox->pack_start($widget, 0, 1, 0);
	
    my $button = new Gtk::Button "OK";
    $button->signal_connect("clicked" => sub {
	$dialog->destroy; });
    $button->can_default(1);
    $dialog->action_area->pack_start($button, 0, 1, 0);
    $button->grab_default;
    $button->show;
    if (!$dialog->visible) {
	$dialog->show;
    } else {
	$dialog->destroy;
    };
}

sub create_mainwindow {
    my(
       $box,
       $box1,
       $box2,
       $accel_group,
       $menu,
       $button,
       $scroller,
       $list,
       $list_item,
       $separator,
       $frame,
       $label,
       $group,
       $transparent,
       $buffer,
       $test
       );
    
    if (not defined $window) {
	
	$window = new Gtk::Window( 'toplevel' );
	
	$window->set_title("GPerlbotCFG");
	$window->set_uposition(20, 20);
	$window->set_usize(800, 600);
	
	$window->border_width(0);
	$window->signal_connect("destroy" => \&Gtk::main_quit);
	$window->signal_connect("delete_event" => \&Gtk::false);
	
	$box1 = new Gtk::VBox 0, 0;
	$window->add($box1);
	
	$accel_group = new Gtk::AccelGroup;
	$menu = new Gtk::ItemFactory('Gtk::MenuBar', "<main>", $accel_group);
	
	$accel_group->attach($window);
	foreach (@menu_entries) {
	    $menu->create_item($_, \&menu_cb);
	}
	
	$box1->pack_start($menu->get_widget('<main>'), 0, 0, 0);
	$box2 = new Gtk::HBox 0, 5;
	$box2->border_width(5);
	$box1->pack_start($box2, 1, 1, 0);

	$notebook = new Gtk::Notebook;
	$notebook->signal_connect( 'switch_page', \&notebook_page_switch );
	$notebook->set_tab_pos(-top);
	$notebook->border_width($bwidth);
	
	$scroller = new Gtk::ScrolledWindow(undef, undef);
	$scroller->border_width(5);
	$scroller->set_policy(-automatic, -automatic);
	
	$plugin_list = new Gtk::List;
	$plugin_list->signal_connect("select_child" => sub { 
	    plugin_select($_[1]->{plugin}); });

	$plugin_list->set_selection_mode(-single);
	$plugin_list->set_selection_mode(-browse);
  	$scroller->add_with_viewport($plugin_list);
	$test = check_for_files;

  	$buffer = "Plugins";

	$frame = new Gtk::Frame( $buffer );

	$frame->add( $scroller );
	$frame->show_all();
    
	$box2->pack_start($frame, 0, 0, 0);
	$box2->pack_start($notebook, 1, 1, 0);

	$notebook->realize;
	$notebook->popup_enable;			
	
    }
    
    if (! $window->visible) {
	$window->show_all();
	if ($test == 2){
	    my $vbox = new Gtk::VBox 0, 0;
	    $vbox->border_width($bwidth);
	    
	    $label = new Gtk::Label
		('The specified file is not a valid config file,');
	    $vbox->pack_start($label, 0, 1, 0);
	    $label->show;
	    
	    $label = new Gtk::Label
		('trying file "config" in current directory, or else starting new.');
	    $vbox->pack_start($label, 0, 1, 0);
	    $label->show;

	    create_dialog($vbox, 1, 0,'Bad Config File');
	}
    } else {
	$window->destroy();
    }
}

create_mainwindow;

main Gtk;

Gtk->exit(0);














