# MAPLAT  (C) 2008-2010 Rene Schickbauer
# Developed under Artistic license
# for Magna Powertrain Ilz
package Maplat::Worker::Logging;
use strict;
use warnings;

use English;

our $VERSION = 0.99;

#=!=START-AUTO-INCLUDES
use Maplat::Worker::Logging::Graphs;
use Maplat::Worker::Logging::PAC3200;
use Maplat::Worker::Logging::USV;
#=!=END-AUTO-INCLUDES


1;
__END__

=head1 NAME

Maplat::Worker::Logging - load the Maplat::Web::Logging:: plugins

=head1 SYNOPSIS

This module loads all Maplat::Worker::Logging:: plugins. This should be used
before configuring the modules.

  use Maplat::Worker;
  use Maplat::Worker::Logging;


=head1 DESCRIPTION

This module loads all Maplat::Worker::Logging:: plugins. This should be used
before configuring the modules.


=head1 SEE ALSO

Maplat::Worker::Logging::Graphs
Maplat::Worker::Logging::PAC3200
Maplat::Worker::Logging::USV

Please also take a look in the example provided in the tarball available on CPAN.

=head1 AUTHOR

Rene Schickbauer, E<lt>rene.schickbauer@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2010 by Rene Schickbauer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
