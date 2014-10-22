#!perl

use strict;
use warnings;

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

use Test::More;
use Test::DZil;
use Test::Exception;

use File::Temp;
use File::Path;
use Class::Load;
use Dist::Zilla::Tester;

no warnings qw(redefine once);

#------------------------------------------------------------------------------
# Much of this test was deduced from:
#
#  https://metacpan.org/source/RJBS/Dist-Zilla-4.300016/t/plugins/uploadtocpan.t
#
# But it isn't clear how much of the D::Z testing API is actually stable and
# public.  So I wouldn't be surpised if these tests start failing with newer
# D::Z.
#------------------------------------------------------------------------------

my $has_pinto_tester = Class::Load::try_load_class('Pinto::Tester');
plan skip_all => 'Pinto::Tester required' if not $has_pinto_tester;

my $has_pinto = Class::Load::try_load_class('Pinto');
plan skip_all => 'Pinto required' if not $has_pinto;


#------------------------------------------------------------------------------
# Most load this *after* checking to see if we have Pinto and Pinto::Tester

use_ok('Dist::Zilla::Plugin::Pinto::Add')
  or BAIL_OUT('Does not compile, do not bother testing the rest');

#------------------------------------------------------------------------------
# TODO: Most of 01-remote.t and 02-remote.t are identical.  The only difference
# is the use of a local repository vs. a remote one.  So factor out these
# differences and consolidate them into one test script.
#------------------------------------------------------------------------------

sub build_tzil {

  my $dist_ini = simple_ini('GatherDir', 'ModuleBuild', @_);

  return Builder->from_config(
    { dist_root => 'corpus/dist/DZT' },
    { add_files => {'source/dist.ini' => $dist_ini} } );
}

#---------------------------------------------------------------------
# simple release

{

  my $t     = Pinto::Tester->new;
  my $root  = $t->pinto->root->stringify;
  my $tzil  = build_tzil( ['Pinto::Add' => {root    => $root,
                                            pauserc => ''}] );
  $tzil->release;

  $t->registration_ok("AUTHOR/DZT-Sample-0.001/DZT::Sample~0.001/");
}

#---------------------------------------------------------------------
# release to a stack

{

  my $t     = Pinto::Tester->new;
  $t->run_ok('New', {stack => 'test'});

  my $root  = $t->pinto->root->stringify;
  my $tzil  = build_tzil( ['Pinto::Add' => {root    => $root,
                                            stack   => 'test',
                                            pauserc => ''}] );
  $tzil->release;

  $t->registration_ok("AUTHOR/DZT-Sample-0.001/DZT::Sample~0.001/test");
}


#---------------------------------------------------------------------
# read author from pauserc

{
  my $pauserc = File::Temp->new;
  print {$pauserc} "user PAUSEID\n";
  my $pause_file = $pauserc->filename;

  my $t     = Pinto::Tester->new;
  my $root  = $t->pinto->root->stringify;
  my $tzil  = build_tzil( ['Pinto::Add' => {root    => $root,
                                            pauserc => $pause_file}] );

  $tzil->release;

  $t->registration_ok("PAUSEID/DZT-Sample-0.001/DZT::Sample~0.001/");
}

#---------------------------------------------------------------------
# read author from dist.ini

{
  my $t     = Pinto::Tester->new;
  my $root  = $t->pinto->root->stringify;
  my $tzil  = build_tzil( ['Pinto::Add' => {root   => $root,
                                            author => 'AUTHORID'}] );

  $tzil->release;

  $t->registration_ok("AUTHORID/DZT-Sample-0.001/DZT::Sample~0.001/");
}

#---------------------------------------------------------------------
# prompt for username/password

{
  my ($username, $password);

  # Intercept release() method and record some attributes
  local *Dist::Zilla::Plugin::Pinto::Add::release = sub {
    ($username, $password) = ($_[0]->username, $_[0]->password);
  };

  my $t     = Pinto::Tester->new;
  my $root  = $t->pinto->root->stringify;
  my $tzil  = build_tzil( ['Pinto::Add' => { root         => $root,
                                             authenticate => 1}] );

  $tzil->chrome->set_response_for('Pinto username: ', 'myusername');
  $tzil->chrome->set_response_for('Pinto password: ', 'mypassword');

  $tzil->release;

  is $password, 'mypassword', 'got password from prompt';
  is $username, 'myusername', 'got username from prompt';
}

#---------------------------------------------------------------------
# username/password from dist.ini

{
  my ($username, $password);

  # Intercept release() method and record some attributes
  local *Dist::Zilla::Plugin::Pinto::Add::release = sub {
    ($username, $password) = ($_[0]->username, $_[0]->password);
  };

  my $t     = Pinto::Tester->new;
  my $root  = $t->pinto->root->stringify;
  my $tzil  = build_tzil( ['Pinto::Add' => { root     => $root,
                                             username => 'myusername',
                                             password => 'mypassword',
                                             authenticate => 1}] );
  $tzil->release;

  is $password, 'mypassword', 'got password from dist.ini';
  is $username, 'myusername', 'got username from dist.ini';
}

#---------------------------------------------------------------------
# demand password

{
  my $t     = Pinto::Tester->new;
  my $root  = $t->pinto->root->stringify;
  my $tzil  = build_tzil( ['Pinto::Add' => { root     => $root,
                                             username => 'myusername',
                                             authenticate => 1}] );

  throws_ok { $tzil->release }
    qr/need to supply a password/, "demanded password";
}


#---------------------------------------------------------------------
# multiple repositories

{
  my ($t1, $t2)  = map { Pinto::Tester->new } (1,2);
  my ($root1, $root2) = map { $_->root->stringify } ($t1, $t2);

  my $tzil  = build_tzil( ['Pinto::Add' => { root   => [$root1, $root2],
                                             author => 'AUTHORID' }] );

  $tzil->release;

  $t1->registration_ok("AUTHORID/DZT-Sample-0.001/DZT::Sample~0.001/");
  $t2->registration_ok("AUTHORID/DZT-Sample-0.001/DZT::Sample~0.001/");
}

#---------------------------------------------------------------------
# one of the repositories is locked -- abort release

{

  diag("You will see some warnings here.  Do not be alarmed.");

  my ($t1, $t2) = map { Pinto::Tester->new } (1,2);
  my ($root1, $root2) = map { $_->root->stringify } ($t1, $t2);

  $t2->pinto->repo->lock('EX');

  my $tzil  = build_tzil( ['Pinto::Add' => { root   => [$root1, $root2],
                                             author => 'AUTHORID' }] );

  local $Pinto::Locker::LOCKFILE_TIMEOUT = 5;
  my $prompt = "repository at $root2 is not available.  Abort the rest of the release?";

  $tzil->chrome->set_response_for($prompt, 'Y');
  throws_ok { $tzil->release } qr/Aborting/;

  $t1->repository_clean_ok;
  $t2->repository_clean_ok;
}

#---------------------------------------------------------------------
# one of the repositories is locked -- partial release

{

  diag("You will see some warnings here.  Do not be alarmed.");

  my ($t1, $t2) = map { Pinto::Tester->new } (1,2);
  my ($root1, $root2) = map { $_->root->stringify } ($t1, $t2);

  $t2->pinto->repo->lock('EX');

  my $tzil  = build_tzil( ['Pinto::Add' => { root   => [$root1, $root2],
                                             author => 'AUTHORID' }] );

  local $Pinto::Locker::LOCKFILE_TIMEOUT = 5;
  my $prompt = "repository at $root2 is not available.  Abort the rest of the release?";

  $tzil->chrome->set_response_for($prompt, 'N');
  $tzil->release;

  $t1->registration_ok("AUTHORID/DZT-Sample-0.001/DZT::Sample~0.001/");
  $t2->repository_clean_ok;
}

#---------------------------------------------------------------------
# Clean up after Test::DZil;

eval { rmtree('tmp') } if -e 'tmp';

#------------------------------------------------------------------------------
done_testing;
