
use strict;
use warnings;

use Module::Build 0.3601;
use lib 'inc'; use Dist::Zilla::Plugin::Pinto::Add::Module::Build;

my %module_build_args = (
  "build_requires" => {
    "Dist::Zilla::Tester" => 0,
    "File::Find" => 0,
    "File::Path" => 0,
    "File::Temp" => 0,
    "File::Which" => 0,
    "Module::Build" => "0.3601",
    "Test::DZil" => 0,
    "Test::Exception" => 0,
    "Test::More" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Add your dist to a Pinto repository",
  "dist_author" => [
    "Jeffrey Ryan Thalhammer <jeff\@imaginative-software.com>"
  ],
  "dist_name" => "Dist-Zilla-Plugin-Pinto-Add",
  "dist_version" => "0.046",
  "license" => "perl",
  "module_name" => "Dist::Zilla::Plugin::Pinto::Add",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Class::Load" => 0,
    "Dist::Zilla::Role::BeforeRelease" => 0,
    "Dist::Zilla::Role::Releaser" => 0,
    "English" => 0,
    "File::HomeDir" => 0,
    "Moose" => 0,
    "Moose::Util::TypeConstraints" => 0,
    "MooseX::Types::Moose" => 0,
    "Path::Class" => 0,
    "Pinto::Role::PauseConfig" => 0,
    "Pinto::Types" => 0,
    "Try::Tiny" => 0,
    "perl" => "5.006"
  },
  "script_files" => []
);


my $build = Dist::Zilla::Plugin::Pinto::Add::Module::Build->new(%module_build_args);

$build->create_build_script;
