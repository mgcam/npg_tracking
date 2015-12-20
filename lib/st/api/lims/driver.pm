package st::api::lims::driver;

use Moose;
use Class::Load qw(load_class);
use Readonly;
use Carp;
use namespace::autoclean;

use npg_tracking::util::types;
use st::api::lims;

with qw/ 
         npg_tracking::glossary::tag
         npg_tracking::glossary::flowcell
       /;

our $VERSION = '0';

Readonly::Scalar my $XML_DRIVER_NAME         => 'xml';
Readonly::Scalar my $WH_DRIVER_NAME          => 'warehouse';
Readonly::Scalar my $MLWH_DRIVER_NAME        => 'ml_warehouse';
Readonly::Scalar my $SAMPLESHEET_DRIVER_NAME => 'samplesheet';


has 'id_run'    =>   (isa       => 'NpgTrackingRunId',
                      is        => 'ro',
                      required  => 0,
);

has 'position'  =>   (isa       => 'NpgTrackingLaneNumber',
                      is        => 'ro',
                      required  => 0,
);

has 'driver_type'  => (isa        => 'Str',
                       is         => 'ro',
                       required   => 0,
                       lazy_build => 1,
);
sub _build_driver_type {
  my $self = shift;
  return $self->_samplesheet_path ? $SAMPLESHEET_DRIVER_NAME : $MLWH_DRIVER_NAME;
}

has 'wh_schema'  => (isa        => 'npg_warehouse::Schema',
                     is         => 'ro',
                     required   => 0,
                     lazy_build => 1,
);
sub _connect {
  my $dbix_class_name = shift;
  load_class $dbix_class_name;
  return $dbix_class_name->connect();
}
sub _build_wh_schema {
  _connect('npg_warehouse::Schema');
}

has 'mlwh_schema' => (
                isa        => 'WTSI::DNAP::Warehouse::Schema',
                is         => 'ro',
                required   => 0,
                lazy_build => 1,
);
sub _build_mlwh_schema {
  _connect('WTSI::DNAP::Warehouse::Schema');
}

has '_samplesheet_path' => (
                isa        => 'Maybe[Str]',
                is         => 'ro',
                required   => 0,
                lazy_build => 1,
);
sub _build__samplesheet_path {
  return $ENV{st::api::lims->cached_samplesheet_var_name()};
}

has '_driver_package' => (
                isa        => 'Str',
                is         => 'ro',
                required   => 0,
                lazy_build => 1,
);
sub _build__driver_package {
  my $self = shift;

  my $delim = q[::];
  my @comp = split /$delim/, __PACKAGE__;
  pop @comp;
  return join $delim, @comp, $self->driver_type;
}

sub create_driver {
  my $self = shift;

  my $driver_type = $self->driver_type;
  load_class $self->_driver_package;
  my $method_name = join q[_], q[], $driver_type, 'driver';

  if (!$self->can($method_name)) {
    croak "Driver type $driver_type is not supported";
  }
  
  return $self->$method_name;
}

sub _run_position_tag_info {
  my $self = shift;
  my $h = {};
  for my $attr (qw/id_run position tag_index/) {
    if (defined $self->$attr) {
      $h->{$attr} = $self->$attr;
    }
  }
  return $h;
}

sub _ml_warehouse_driver {
  my $self = shift;
  
  ($self->id_flowcell_lims || $self->flowcell_barcode || $self->id_run) ||
      croak 'Either id_flowcell_lims or flowcell_barcode or id_run shoudl be defined';

  my $ref = $self->_run_position_tag_info();
  $ref->{'mlwh_schema'} = $self->mlwh_schema;
  $ref->{'id_flowcell_lims'} = $self->id_flowcell_lims;
  $ref->{'flowcell_barcode'} = $self->flowcell_barcode;

  return $self->_driver_package->new($ref);
}

sub _warehouse_driver {
  my $self = shift;

  if (!$self->id_flowcell_lims) {
    croak 'id_flowcell_lims should be defined';
  }

  return $self->_driver_package->new(
    npg_warehouse_schema => $self->wh_schema,
    position             => 1, # MiSeq only
    tube_ean13_barcode   => $self->id_flowcell_lims
  );
}

sub _xml_driver {
  my $self = shift;

  ($self->id_run || $self->id_flowcell_lims) ||
    croak 'Either id_run or id_flowcell_lims should be defined';
   
  my $ref = $self->_run_position_tag_info();
  if ($self->id_flowcell_lims) {
    $ref->{'batch_id'} = $self->id_flowcell_lims;
  }

  return $self->_driver_package->new($ref);
}

sub _samplesheet_driver {
  my $self = shift;

  my $ref = $self->_run_position_tag_info();
  $ref->{'path'} = $self->_samplesheet_path;
  
  return $self->_driver_package->new($ref);
}

sub xml_driver_name {
  return $XML_DRIVER_NAME;
}

sub warehouse_driver_name {
  return $WH_DRIVER_NAME;
}

sub mlwarehouse_driver_name {
  return $MLWH_DRIVER_NAME;
}

sub samplesheet_driver_name {
  return $SAMPLESHEET_DRIVER_NAME;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

st::api::lims::driver

=head1 SYNOPSIS

  my $driver = st::api::lims::driver->new(
    id_run           => 3456,
    id_flowcell_lims => 678,
    driver_type      => 'xml'
  )->create_driver();
  print ref $driver; prints 'st::api::lims::xml'

  my $factory = st::api::lims::driver->new(
    flowcell_barcode => 'HT7GKADXX',
    id_flowcell_lims => 17678,
  )
  print $factory->driver_type; # prints 'ml_warehouse'
  $driver = $factory->create_driver();
  print ref $driver; prints 'st::api::lims::ml_warehouse'
  

  $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = 'some_file';
  $factory = st::api::lims::driver->new(
    flowcell_barcode => 'HT7GKADXX',
    id_flowcell_lims => 17678,
  )
  print $factory->driver_type; # prints 'samplesheet'
  $driver = $factory->create_driver();
  print ref $driver; prints 'st::api::lims::samplesheet'

=head1 DESCRIPTION

A factory class for generating LIMs drivers that can be supplied to the
'driver' attribute of the at::api::lims class.

The package has no hard dependencies on driver packages or their dependencies.
At the time of creating an instance of a driver, relevant dependencies
are loaded into memory. Attributes wh_schema and mlwh_schema are
exposed in order to pass a database handle to driver objects for LIMs
bindings that retrieve data from a database.

The constructor is not strict, i.e. it will accept any attributes.
However, not all of the attributes will be used during a driver object
creation. In particular, the position and tag_index attributes are never
passed to driver objects' constructors.

=head1 SUBROUTINES/METHODS

=head2 id_run
 
Integer run id, an optional attribute.

=head2 flowcell_barcode

Manufacturer flowcell barcode/id, an optional attribute.

=head2 id_flowcell_lims

LIMs specific flowcell id, an optional attribute.

=head2 driver_type
 
Lims driver type, an optional attribute. If NPG_CACHED_SAMPLESHEET_FILE
environment variable is set, defaults to 'samplesheet', otherwise
defaults to 'ml_warehouse'. Other two possible values are
'xml' and 'warehouse'.

=head2 wh_schema
 
DBIx schema class for old warehouse access, an optional attribute.

=head2 mlwh_schema
 
DBIx schema class for ml_warehouse access, an optional attribute.

=head2 create_driver

A factory method returning an instance of a LIMs driver object of
type defined by the driver_type attribute.

=head2 xml_driver_name

  Returns xml driver type name.
  Can be used either as a class or object instance method.

=head2 warehouse_driver_name

  Returns warehouse driver type name.
  Can be used either as a class or object instance method.

=head2 mlwarehouse_driver_name

  Returns ml_warehouse driver type name.
  Can be used either as a class or object instance method.

=head2 samplesheet_driver_name

  Returns samplesheet driver type name.
  Can be used either as a class or object instance method.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Class::Load

=item Readonly

=item Carp

=item namespace::autoclean

=item npg_tracking::util::types

=item st::api::lims

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
