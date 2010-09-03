#!/usr/bin/perl
use 5.008;
use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    module_name => 'Method::Workflow::SPEC',
    license     => 'perl',
    dist_author => 'Chad Granum <exodist7@gmail.com>',
    create_readme => 1,
    requires => {
        'Carp'             => 0,
        'List::Util'       => 0,
        'Method::Workflow' => '0.006',
        'Scalar::Util'     => 0,
        'Try::Tiny'        => 0,
        'aliased'          => 0,
    },
    build_requires => {
        'Test::More' => 0.88,
        'Test::Exception' => 0,
    },
    meta_merge => {
        resources => {
            repository => 'http://github.com/exodist/Method-Workflow-SPEC',
            bugtracker => 'http://github.com/exodist/Method-Workflow-SPEC/issues',
            homepage   => 'http://open-exodus.net/projects/Method-Workflow-SPEC'
        },
    }
);

$build->create_build_script;
