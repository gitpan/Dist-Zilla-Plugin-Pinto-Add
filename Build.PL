
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'File::Find' => '0',
    'File::Temp' => '0',
    'Module::Build' => '0.3601',
    'Test::More' => '0'
  },
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'Add your dist to a Pinto repository',
  'dist_author' => [
    'Jeffrey Ryan Thalhammer <jeff@imaginative-software.com>'
  ],
  'dist_name' => 'Dist-Zilla-Plugin-Pinto-Add',
  'dist_version' => '0.004',
  'license' => 'perl',
  'module_name' => 'Dist::Zilla::Plugin::Pinto::Add',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'Class::Load' => '0',
    'Dist::Zilla::Role::Releaser' => '0',
    'English' => '0',
    'Moose' => '0',
    'MooseX::Types::Moose' => '0',
    'Pinto::Types' => '0',
    'perl' => '5.006'
  },
  'script_files' => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
