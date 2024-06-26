package A;
sub b { }
sub c { }
1;

package Bar;
sub foo { }
sub user { }
sub id { }
sub edit { }
sub del { }
sub change { }
sub change_name { }
sub change_email { }
1;

package Bar::Foo;
sub baz { }
1;

use strict;
use warnings;

BEGIN {
    my $DOWARN = 0;
    $SIG{'__WARN__'} = sub { warn $_[0] if $DOWARN }
}

use Test::More;
use Kelp::Routes;

my $r = Kelp::Routes->new;

# Basic
#
{
    $r->add( '/a' => 'a#b' );
    is_deeply _d( $r, qw/pattern to/ ), [
        {
            pattern => '/a',
            to      => 'A::b'
        }
      ];
}

# Via method
#
{
    $r->clear;
    $r->add( [ POST => '/a' ] => 'a#b' );
    is_deeply _d( $r, qw/method pattern to/ ), [
        {
            method  => 'POST',
            pattern => '/a',
            to      => 'A::b'
        }
      ];
}

# Odd method
#
{
    $r->clear;
    $r->add( [ MOST => '/a' ] => 'a#b' );
    is_deeply _d( $r, qw/method pattern to/ ), [
        {
            method  => 'MOST',
            pattern => '/a',
            to      => 'A::b'
        }
      ];
}

# Sub
#
{
    $r->clear;
    $r->add( '/a' => sub { } );
    is ref( $r->routes->[0]->to ), 'CODE';
}

# Not hash
#
{
    $r->clear;
    $r->add( '/a' => [] );
    is_deeply $r->routes, [];
}

# Weird key
#
{
    $r->clear;
    $r->add( { a => 1 }, 'a#b' );
    is_deeply $r->routes, [];

    $r->add( [ POST => { a => 1 } ], 'a#b' );
    is_deeply $r->routes, [];
}

# Missing destination
#
{
    $r->clear;
    $r->add( '/a' => { name => 'a' } );
    is_deeply $r->routes, [];
}

# Key trumps method in the value
{
    $r->clear;
    $r->add( [ POST => '/a' ] => { to => 'a#b', method => 'PUT' } );
    is_deeply _d( $r, qw/method/ ), [ { method => 'POST' } ];
}

# Regex
#
{
    $r->clear;
    my $re = qr{^/a/(\w+)$};
    $r->add( $re, 'bar#foo' );
    is_deeply _d( $r, qw/pattern/ ), [
        {
            pattern => $re
        }
      ];
}

# Hash
#
{
    $r->clear;
    my $hash = {
        name  => 'james',
        check => { a => '\d' },
        to    => 'bar#foo'
    };
    $r->add( '/:a' => $hash );
    is_deeply _d( $r, qw/name check to/ ), [
        {
            name  => 'james',
            check => { a => '\d' },
            to    => 'Bar::foo'
        }
      ];
}

# Base
#
{
    $r->clear;
    $r->base('Bar');
    $r->add( '/a' => 'foo#baz' );
    is_deeply _d( $r, qw/to/ ), [
        {
            to => 'Bar::Foo::baz'
        }
      ];
    $r->base('');
}

# Base + fully qualified name
{
    $r->clear;
    $r->base('Bar');
    $r->add( '/a' => '+Plack::Util::load_class' );
    is_deeply _d( $r, qw/to/ ), [
        {
            to => 'Plack::Util::load_class'
        }
      ];

    $r->clear;
    $r->add( '/a' => '+plack#util#load_class');
    is_deeply _d( $r, qw/to/ ), [
        {
            to => 'Plack::Util::load_class'
        }
      ];

    $r->base('');
}

# Tree
#
{

    # Tree not ARRAY
    $r->clear;
    $r->add(
        '/user' => {
            tree => { a => 1, b => 2 }
        }
    );
    is_deeply $r->routes, [];

    # Tree no name
    $r->clear;
    $r->add(
        '/a' => {
            to   => 'a#b',
            tree => [
                '/b' => { name => 'b', to => 'a#b' },
                '/c' => 'a#c'
            ]
        }
    );
    is_deeply _d( $r, 'name' ), [ {}, { name => 'b' }, {} ];

    # Good tree
    $r->clear;
    $r->add(
        '/user' => {
            name => 'user',
            to   => 'bar#user',
            tree => [
                '/id'   => { to => 'bar#id',   name => 'id' },
                '/edit' => { to => 'bar#edit', name => 'edit' },
                [ DELETE => '/id' ] => { to => 'bar#del' => name => 'delete' },
                '/change' => {
                    to   => 'bar#change',
                    name => 'change',
                    tree => [
                        '/name' => { to => 'bar#change_name', name => 'name' },
                        [ PUT  => '/email' ] =>
                          { to => 'bar#change_email', name => 'email' }
                    ]
                }
            ]
        }
    );

    is_deeply _d( $r, qw/pattern name to method/ ), [
        {
            pattern => '/user',
            name    => 'user',
            to      => 'Bar::user',
        }, {
            pattern => '/user/id',
            name    => 'user_id',
            to      => 'Bar::id',
        }, {
            pattern => '/user/edit',
            name    => 'user_edit',
            to      => 'Bar::edit',
        }, {
            pattern => '/user/id',
            name    => 'user_delete',
            to      => 'Bar::del',
            method  => 'DELETE'
        }, {
            pattern => '/user/change',
            name    => 'user_change',
            to      => 'Bar::change'
        }, {
            pattern => '/user/change/name',
            name    => 'user_change_name',
            to      => 'Bar::change_name'
        }, {
            pattern => '/user/change/email',
            name    => 'user_change_email',
            to      => 'Bar::change_email',
            method  => 'PUT'
        }
      ];
}

# Returned locations
{
    # same tree as above
    $r->clear;

    my $user = $r->add( '/user' => { name => 'user', to   => 'bar#user', } );
    $user->add( '/id' => { to => 'bar#id',   name => 'id' } );
    $user->add( '/edit' => { to => 'bar#edit', name => 'edit' } );
    $user->add( [ DELETE => '/id' ] => { to => 'bar#del' => name => 'delete' } );

    my $change = $user->add( '/change' => { to   => 'bar#change', name => 'change' } );
    $change->add( '/name' => { to => 'bar#change_name', name => 'name' } );
    $change->add( [ PUT  => '/email' ] => { to => 'bar#change_email', name => 'email' } );

    is_deeply _d( $r, qw/pattern name to method bridge/ ), [
        {
            pattern => '/user',
            name    => 'user',
            to      => 'Bar::user',
            bridge  => !!1,
        }, {
            pattern => '/user/id',
            name    => 'user_id',
            to      => 'Bar::id',
            bridge  => !!0,
        }, {
            pattern => '/user/edit',
            name    => 'user_edit',
            to      => 'Bar::edit',
            bridge  => !!0,
        }, {
            pattern => '/user/id',
            name    => 'user_delete',
            to      => 'Bar::del',
            method  => 'DELETE',
            bridge  => !!0,
        }, {
            pattern => '/user/change',
            name    => 'user_change',
            to      => 'Bar::change',
            bridge  => !!1,
        }, {
            pattern => '/user/change/name',
            name    => 'user_change_name',
            to      => 'Bar::change_name',
            bridge  => !!0,
        }, {
            pattern => '/user/change/email',
            name    => 'user_change_email',
            to      => 'Bar::change_email',
            method  => 'PUT',
            bridge  => !!0,
        }
      ];
}

sub _d {
    my ( $r, @fields ) = @_;
    my @o = ();
    for my $route ( @{ $r->routes } ) {
        my @a = scalar(@fields) ? @fields : keys %{$route};
        my %h = ();
        for my $k (@a) {
            $h{$k} = $route->{$k} if ( defined $route->{$k} );
        }
        push @o, \%h;
    }
    return \@o;
}

done_testing;

