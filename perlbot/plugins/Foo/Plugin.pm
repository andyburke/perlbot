package Foo::Plugin;

sub get_hooks {
    return { public => \&public, msg => \&msg};
}

# when someone says anything containing 'foo' in a channel, the bot will
# respond with 'Bar!@#'
sub public {
    my ($conn, $event) = @_;

    do_foo($conn, ($event->to)[0], ($event->args)[0]);
}

# same as public, but for private msgs
sub msg {
    my ($conn, $event) = @_;

    do_foo($conn, $event->nick, ($event->args)[0]);
}

sub do_foo {
    my ($conn, $from, $args) = @_;

    if ($args !~ /^[!\#]/ and $args =~ /foo/i) {
	$conn->privmsg($from, 'Bar!@#');
    }
}

1;
