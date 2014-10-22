# ABSTRACT: Ship your dist to a Pinto repository

package Dist::Zilla::Plugin::Pinto::Add;

#------------------------------------------------------------------------------
# If Pinto has been installed as a stand-alone application into the
# PINTO_HOME directory, then we should load all libraries from there.

BEGIN {

    my $home_var = 'PINTO_HOME';
    my $home_dir = $ENV{PINTO_HOME};

    if ($home_dir) {
        require File::Spec;
        my $lib_dir = File::Spec->catfile($home_dir, qw(lib perl5));
        die "$home_var ($home_dir) does not exist!\n" unless -e $home_dir;
        eval qq{use lib '$lib_dir'; 1} or die $@; ## no critic (Eval)
    }
}

#------------------------------------------------------------------------------

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Moose qw(Str ArrayRef Bool);

use Carp;
use Try::Tiny;
use Class::Load;

use Pinto::Util qw(current_author_id current_username);
use Pinto::Types qw(AuthorID StackName StackDefault);

#------------------------------------------------------------------------------

our $VERSION = '0.082'; # VERSION

#------------------------------------------------------------------------------

with qw( Pinto::Role::PauseConfig
         Dist::Zilla::Role::BeforeRelease
         Dist::Zilla::Role::Releaser );

#------------------------------------------------------------------------------

class_type('Pinto');
class_type('Pinto::Remote');

#------------------------------------------------------------------------------

sub mvp_multivalue_args { return qw(root) }

#------------------------------------------------------------------------------

has root => (
    isa        => ArrayRef[Str],
    traits     => [ qw(Array) ],
    handles    => {root => 'elements'},
    required   => 1,
);


has author => (
    is         => 'ro',
    isa        => AuthorID,
    default    => sub { uc ($_[0]->pausecfg->{user} || '') || current_author_id },
    lazy       => 1,
);


has no_recurse => (
    is         => 'ro',
    isa        => Bool,
    default    => 0,
);


has stack     => (
    is        => 'ro',
    isa       => StackName | StackDefault,
    default   => undef,
);


has authenticate => (
    is => 'ro',
    isa => Bool,
    default => 0,
);


has username => (
    is   => 'ro',
    isa  => Str,
    lazy => 1,
    required => 1,
    default  => sub {
        my ($self) = @_;
        return $self->zilla->chrome->prompt_str('Pinto username: ', { default => current_username });
    },
);


has password => (
    is   => 'ro',
    isa  => Str,
    lazy => 1,
    required => 1,
    default  => sub {
        my ($self) = @_;
        return $self->zilla->chrome->prompt_str('Pinto password: ', { noecho => 1 });
    },
);


has pintos => (
    isa        => ArrayRef['Pinto | Pinto::Remote'],
    traits     => [ qw(Array) ],
    handles    => {pintos => 'elements'},
    builder    => '_build_pintos',
    init_arg   => undef,
    lazy       => 1,

);

#------------------------------------------------------------------------------

sub _build_pintos {
    my ($self) = @_;

    # TODO: Need more control over the minimum Pinto or
    # Pinto::Remote version that is required.
    my $version = $self->VERSION;
    my $options = { -version => $version };
    my @pintos;

    for my $root ($self->root) {
        my ($type, $class)  = $root =~ m{^ http:// }mx ? ('remote', 'Pinto::Remote')
                                                       : ('local',  'Pinto');

        my %auth_args = $self->authenticate && $class->isa('Pinto::Remote')
            ? ( username => $self->username, password => $self->password )
            : ();

        $self->log_fatal("You must install $class-$version to release to a $type repository: $@")
            if not eval { Class::Load::load_class($class, $options); 1 };

        my $pinto = try   { $class->new(root => $root, %auth_args) }
                    catch { $self->log_fatal($_) };

        push(@pintos, $pinto) if $self->_ping_it($pinto);
    }

    $self->log_fatal('none of your repositories are available') if not @pintos;
    return \@pintos;
}

#------------------------------------------------------------------------------

sub _ping_it {
    my ($self, $pinto) = @_;

    my $root  = $pinto->root;
    $self->log("checking if repository at $root is available");

    my $ok = try   { $pinto->run('Nop')->was_successful };
    return 1 if $ok;

    my $msg = "repository at $root is not available.  Abort the rest of the release?";
    my $abort  = $self->zilla->chrome->prompt_yn($msg, {default => 'Y'});
    $self->log_fatal('Aborting') if $abort; # dies!
    return 0;
}

#------------------------------------------------------------------------------

sub before_release
{
    my $self = shift;

    return if not $self->authenticate;
    my $problem;
    try {
        for my $attr (qw(username password))
        {
            $problem = $attr;
            croak unless length $self->$attr;
        }
        undef $problem;
    };

    $self->log_fatal(['You need to supply a %s', $problem]) if $problem;

    return 1;
}

#------------------------------------------------------------------------------

sub release {
    my ($self, $archive) = @_;

    for my $pinto ( $self->pintos ) {

        my $root  = $pinto->root;
        $self->log("adding $archive to repository at $root");

        my $result = $pinto->run( 'Add', archives   => [ $archive->stringify ],
                                         author     => $self->author,
                                         stack      => $self->stack,
                                         no_recurse => $self->no_recurse,
                                         message    => "Added $archive" );

        $result->was_successful ? $self->log("added $archive to $root ok")
                                : $self->log_fatal("failed to add $archive to $root: $result");

        # TODO: Should we try to release to all pintos, even if one fails?
    }

    return 1;
}

#------------------------------------------------------------------------------
1;

__END__

=pod

=for :stopwords Jeffrey Ryan Thalhammer BeforeRelease cpan testmatrix url annocpan anno
bugtracker rt cpants kwalitee diff irc mailto metadata placeholders
metacpan

=head1 NAME

Dist::Zilla::Plugin::Pinto::Add - Ship your dist to a Pinto repository

=head1 VERSION

version 0.082

=head1 SYNOPSIS

  # In your dist.ini
  [Pinto::Add]
  root          = http://pinto.my-host      ; at lease one root is required
  author        = YOU                       ; optional. defaults to username
  stack         = stack_name                ; optional. defaults to undef
  no_recurse    = 1                         ; optional. defaults to 0
  authenticate  = 1                         ; optional. defaults to 0
  username      = you                       ; optional. will prompt if needed
  password      = secret                    ; optional. will prompt if needed

  # Then run the release command
  dzil release

=head1 DESCRIPTION

Dist::Zilla::Plugin::Pinto::Add is a release-stage plugin that
will add your distribution to a local or remote L<Pinto> repository.

B<IMPORTANT:> You will need to install L<Pinto> to make this plugin
work.  It ships separately so you can decide how you want to install
it.  I recommend installing Pinto as a stand-alone application as
described in L<Pinto::Manual::Installing> and then setting the
C<PINTO_HOME> environment variable.  Or you can install Pinto from
CPAN using the usual tools.  Either way, this plugin should just do
the right thing to load the necessary modules.

Before releasing, L<Dist::Zilla::Plugin::Pinto::Add> will check if the
repository is responding.  If not, you'll be prompted whether to abort
the rest of the release.

If the C<authenticate> configuration option is enabled, and either the
C<username> or C<password> options are not configured, you will be
prompted you to enter your username and password during the
BeforeRelease phase.  Entering a blank username or password will abort
the release.

=for Pod::Coverage before_release release mvp_multivalue_args

=head1 CONFIGURATION

The following parameters can be set in the F<dist.ini> file for your
distribution:

=over 4

=item root = REPOSITORY

This identifies the root of the Pinto repository you want to release
to.  If C<REPOSITORY> looks like a remote URL (i.e. it starts with
"http://") then your distribution will be shipped with
L<Pinto::Remote>.  Otherwise, the C<REPOSITORY> is assumed to be a
path to a local repository directory and your distribution will be
shipped with L<Pinto>.

At least one C<root> is required.  You can release to multiple
repositories by specifying the C<root> attribute multiple times.  If
any of the repositories are not responding, we will still try to
release to the rest of them (unless you decide to abort the release
altogether).  If none of the repositories are responding, then the
entire release will be aborted.  Any errors returned by one of the
repositories will also cause the rest of the release to be aborted.

=item author = NAME

This specifies your identity as a module author.  It must be
alphanumeric characters (no spaces) and will be forced to UPPERCASE.
If you do not specify one, it defaults to either your PAUSE ID (if you
have one configured in F<~/.pause>) or your current username.

=item stack = NAME

This specifies which stack in the repository to put the released
packages into.  Defaults to C<undef>, which means to use whatever
stack is currently defined as the default by the repository.

=item no_recurse = 0|1

If true, prevents Pinto from recursively importing all the
distributions required to satisfy the prerequisites for the
distribution you are adding.  Default is 0.

=item authenticate = 0|1

Indicates that authentication credentials are required for
communicating with the server (these will be prompted for, if not
provided in the F<dist.ini> file as described below).  Defaults is
false.

=item username = NAME

Specifies the username to use for server authentication.

=item password = PASS

Specifies the password to use for server authentication.

=back

=head1 ENVIRONMENT VARIABLES

The following environment variables can be used to influence the
default values used for some of the parameters above.

=over 4

=item C<PINTO_AUTHOR_ID>

Sets the default author identity, if the C<author> parameter is
not set.

=item C<PINTO_USERNAME>

Sets the default username, if the C<username> parameter is not set.

=back

=head1 RELEASING TO MULTIPLE REPOSITORIES

You can release your distribution to multiple repositories by
specifying multiple values for the C<root> attribute in your
F<dist.ini> file.  In that case, the remaining attributes
(e.g. C<stack>, C<author>, C<authenticate>) will apply to all the
repositories.

However, the recommended way to release to multiple repositories is to
have multiple C<[Pinto::Add]> blocks in your F<dist.ini> file.  This
allows you to set attributes for each repository independently (at the
expense of possibly having to duplicating some information).

=head1 SUPPORT

=head2 Perldoc

You can find documentation for this module with the perldoc command.

  perldoc Dist::Zilla::Plugin::Pinto::Add

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

Search CPAN

The default CPAN search engine, useful to view POD in HTML format.

L<http://search.cpan.org/dist/Dist-Zilla-Plugin-Pinto-Add>

=item *

CPAN Ratings

The CPAN Ratings is a website that allows community ratings and reviews of Perl modules.

L<http://cpanratings.perl.org/d/Dist-Zilla-Plugin-Pinto-Add>

=item *

CPAN Testers

The CPAN Testers is a network of smokers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/D/Dist-Zilla-Plugin-Pinto-Add>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=Dist-Zilla-Plugin-Pinto-Add>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=Dist::Zilla::Plugin::Pinto::Add>

=back

=head2 Bugs / Feature Requests

L<https://github.com/thaljef/Dist-Zilla-Plugin-Pinto-Add/issues>

=head2 Source Code


L<https://github.com/thaljef/Dist-Zilla-Plugin-Pinto-Add>

  git clone git://github.com/thaljef/Dist-Zilla-Plugin-Pinto-Add.git

=head1 AUTHOR

Jeffrey Ryan Thalhammer <jeff@stratopan.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jeffrey Ryan Thalhammer.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
