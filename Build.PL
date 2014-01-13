
use strict;
use warnings;

use Module::Build 0.3601;
use lib qw{inc}; use Dist::Zilla::Plugin::Pinto::Add::Module::Build;

my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601",
    "Module::Build::CleanInstall" => "0.05"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601",
    "Module::Build::CleanInstall" => "0.05"
  },
  "dist_abstract" => "Ship your dist to a Pinto repository",
  "dist_author" => [
    "Jeffrey Ryan Thalhammer <jeff\@stratopan.com>"
  ],
  "dist_name" => "Dist-Zilla-Plugin-Pinto-Add",
  "dist_version" => "0.085",
  "license" => "perl",
  "module_name" => "Dist::Zilla::Plugin::Pinto::Add",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Class::Load" => 0,
    "Dist::Zilla::Role::BeforeRelease" => 0,
    "Dist::Zilla::Role::Releaser" => 0,
    "File::Spec" => 0,
    "Moose" => 0,
    "Moose::Util::TypeConstraints" => 0,
    "MooseX::Types::Moose" => 0,
    "Try::Tiny" => 0,
    "perl" => "5.006"
  },
  "script_files" => [],
  "test_requires" => {
    "Dist::Zilla::Tester" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Path" => 0,
    "File::Spec::Functions" => 0,
    "File::Temp" => 0,
    "File::Which" => 0,
    "List::Util" => 0,
    "Test::DZil" => 0,
    "Test::Exception" => 0,
    "Test::More" => 0,
    "strict" => 0,
    "warnings" => 0
  }
);


my %fallback_build_requires = (
  "Dist::Zilla::Tester" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Path" => 0,
  "File::Spec::Functions" => 0,
  "File::Temp" => 0,
  "File::Which" => 0,
  "List::Util" => 0,
  "Module::Build" => "0.3601",
  "Module::Build::CleanInstall" => "0.05",
  "Test::DZil" => 0,
  "Test::Exception" => 0,
  "Test::More" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Dist::Zilla::Plugin::Pinto::Add::Module::Build->new(%module_build_args);

$build->create_build_script;
