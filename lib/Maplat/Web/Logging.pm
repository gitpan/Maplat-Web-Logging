# MAPLAT  (C) 2008-2010 Rene Schickbauer
# Developed under Artistic license
# for Magna Powertrain Ilz
package Maplat::Web::Logging;
use strict;
use warnings;

# ------------------------------------------
# MAPLAT - Magna ProdLan Administration Tool
# ------------------------------------------

our $VERSION = 0.994;

#=!=START-AUTO-INCLUDES
use Maplat::Web::Logging::Devices;
use Maplat::Web::Logging::Graphs;
use Maplat::Web::Logging::Report;
#=!=END-AUTO-INCLUDES

1;
__END__

=head1 NAME

Maplat::LoggingWeb - Include the Maplat::Web::Logging plugins

=head1 SYNOPSIS

This file loads all the required plugins for Maplat::Web::Logging. It should
be included before configuring the modules.
  
  use Maplat::Web;
  use Maplat::Web::Logging;

=head1 DESCRIPTION

This file loads all the required plugins for Maplat::Web::Logging. It should
be included before configuring the modules.

=head1 WARNING

Warning! If you are upgrading from 0.91 or lower, beware: There are a few incompatible changes in the server
initialization! Please see the Example in the tarball for details.

=head1 SEE ALSO

Maplat::Web::Logging::Devices
Maplat::Web::Logging::Graphs
Maplat::Web::Logging::Report

Please also take a look in the example provided in the tarball available on CPAN.

=head1 AUTHOR

Rene Schickbauer, E<lt>rene.schickbauer@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2010 by Rene Schickbauer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
