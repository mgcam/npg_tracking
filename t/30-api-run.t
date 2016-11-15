use strict;
use warnings;
use Test::More tests => 43;
use Test::Exception;
use t::useragent;
use npg::api::util;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/npg_api];

use_ok('npg::api::run');
my $base_url = $npg::api::util::LIVE_BASE_URI;

my $run1 = npg::api::run->new();
isa_ok($run1, 'npg::api::run', 'constructs ok');
is($run1->id_run(), 0, 'id is zero without constructor args');

my $run2 = npg::api::run->new({'id_run'=>1});
isa_ok($run2, 'npg::api::run', 'constructs ok with args');
is($run2->id_run(), 1, 'yields id from constructor ok');

my $run3 = npg::api::run->new({'id_run'=>'IL45_0456'});
is($run3->id_run(), 456, 'yields id from name');

my $run4 = npg::api::run->new({
             'id_run'      => 457,
             'id_run_pair' => $run3->id_run(),
             'run_pair'    => $run3,
            });
my $run_pair = $run4->run_pair();
is($run3, $run_pair);

is($run3->id_run(999), 999);


{
  my $run  = npg::api::run->new({'id_run' => 2888,});
  my $tags = $run->tags();
  is(scalar @{$tags}, 2, 'correct number of tags for run 2888');
  is($tags->[0], 'rta', 'correct first tag');
}

{
  my $run  = npg::api::run->new({'id_run' => 1104,});
  is($run->is_paired_run(), 0, 'run 1104 is not paired run');
  is($run->is_paired_read(), 0, 'run 1104 is not paired read');
  is($run->is_single_read(), 1, 'run 1104 is single read');
  is($run->team(), 'joint', 'team is joint');
}

{
  my $run  = npg::api::run->new({'id_run' => 1,});
  is($run->is_paired_run(), 0, 'run 1 is paired run');
  is($run->is_paired_read(), 0, 'run 1 is paired read');
  is($run->is_single_read(), 1, 'run 1 is not single read');
}

{
  my $run  = npg::api::run->new({'id_run' => 2888,});
  is($run->is_paired_run(), 0, 'run 2888 is not paired run');
  is($run->is_paired_read(), 0, 'run 2888 is not paired read');
  is($run->is_single_read(), 1, 'run 2888 is single read');
  ok($run->having_control_lane(), 'run 2888 having control lane');
}

{
  my $run  = npg::api::run->new({'id_run' => 2,});
  is($run->is_paired_run(), 0, 'run 2 is not paired run');
  throws_ok { $run->is_paired_read(); } qr{No data on paired/single read available yet}, 'no tag information available for run 2';
  throws_ok { $run->is_single_read(); } qr{No data on paired/single read available yet}, 'no tag information available for run 2 when call is_single_read';
}

{
  my $run  = npg::api::run->new({'id_run' => 1,});

  my $run_lanes = $run->run_lanes();
  is(scalar @{$run_lanes}, 8, 'unprimed cache run_lanes');

  is($run->current_run_status->id_run_status(), 57799);

  my $run_annotations = $run->run_annotations();
  is(scalar @{$run_annotations}, 5);
  is($run_annotations->[0]->id_run_annotation(),665);
}

{
  my $run  = npg::api::run->new({
         'id_run' => 'IL99_FOO',
        });
  is($run->id_run(), 0, 'bad run by name ok');
}

{
  my $run  = npg::api::run->new({
         id_run => 1104,
        });
  my $instrument = $run->instrument();
  isa_ok($instrument, 'npg::api::instrument', 'run->instrument');
  is($instrument->name(), 'IL9');
}

{ 
  my $run  = npg::api::run->new({id_run => 4209,});
  ok(!$run->having_control_lane(), 'run 4209 not having control lane');
  is($run->run_folder, '091218_IL28_4209', 'correct run_folder returned');
}

{
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/npg_api_run];
  my $run  = npg::api::run->new({id_run => 604,});
  isa_ok($run->run_pair(), 'npg::api::run', 'run_pair is run object');
  is($run->run_pair()->id_run(), 636, 'its id_run is 636');
  is($run->run_pair()->batch_id(), $run->batch_id(), 'batch id the same within run pair');

  $run  = npg::api::run->new({id_run => 636,});
  isa_ok($run->run_pair(), 'npg::api::run', 'run_pair is run object');
  is($run->run_pair()->id_run(), 604, 'its id_run is 604');

  my $lims;
  isa_ok($lims = $run->lims(), 'st::api::lims', 'lims accessor returns st::api::lims object');
  is($lims->batch_id, 1001, 'lims object batch id is set correctly');
  is($lims->id_run, 636, 'lims object id_run is set correctly');

  $lims = $run->run_pair->lims();
  is($lims->batch_id, 1001, 'run_pair lims object batch id is set correctly');
  is($lims->id_run, 604, 'run_pair lims object id_run is set correctly');
}

1;

