# MAPLAT  (C) 2008-2010 Rene Schickbauer
# Developed under Artistic license
# for Magna Powertrain Ilz
package Maplat::Worker::Logging::Graphs;
use strict;
use warnings;
use 5.010;

use base qw(Maplat::Worker::BaseModule);

use Maplat::Helpers::DBSerialize;
use Maplat::Helpers::Logging::Graphs;
use Carp;

our $VERSION = 0.99;

sub new {
    my ($proto, %config) = @_;
    my $class = ref($proto) || $proto;
    
    my $self = $class->SUPER::new(%config); # Call parent NEW
    bless $self, $class; # Re-bless with our class

    return $self;
}

sub reload {
    my ($self) = shift;
    # Nothing to do.. in here, we only use the template and database module
    return;
}

sub register {
    my $self = shift;
    
    $self->register_worker("work");
    return;
}

sub work {
    my ($self) = @_;
    
    my $workCount = 0;
    
    my $dbh = $self->{server}->{modules}->{$self->{db}};
    my $reph = $self->{server}->{modules}->{$self->{reporting}};
    my $memh = $self->{server}->{modules}->{$self->{memcache}};
    
    $reph->debuglog("Generating power graphs");
    
    my @hosts;
    my $hoststmt = "SELECT hostname, device_type
                    FROM logging_devices
                    ORDER BY hostname";
    my $hoststh = $dbh->prepare_cached($hoststmt)
            or croak($dbh->errstr);
    $hoststh->execute or croak($dbh->errstr);
    while((my $host = $hoststh->fetchrow_hashref)) {
        $host->{tablename} = 'logging_log_' . lc($host->{device_type});
        push @hosts, $host;
    }
    $hoststh->finish;
    $dbh->rollback;
    
    # Finish up first transaction here, we got all data we need.
    # Worst case scenario: We create some images we can't insert into the table and
    # have a few dummy rollbacks
    
    my $delstmt = "DELETE FROM logging_reportimages
                    WHERE graph_name = ?
                    AND hostname = ?
                    AND device_type = ?
                    AND graph_timeframe = ?";
    my $delsth = $dbh->prepare_cached($delstmt)
            or croak($dbh->errstr);
    
    my $instmt = "INSERT INTO logging_reportimages
                    (graph_name, hostname, device_type, graph_timeframe, graph_data)
                    VALUES
                    (?,?,?,?,?)";
    my $insth = $dbh->prepare_cached($instmt);
    foreach my $host (@hosts) {
        foreach my $ctime (qw[hour day week month year]) {
            my @graphs;
            my $selstmt = "SELECT * FROM logging_reportgraphs
                            WHERE device_type = ?
                            AND custom_graph = 'f'
                            ORDER BY graph_name";
            my $selsth = $dbh->prepare_cached($selstmt)
                    or croak($dbh->errstr);
            $selsth->execute($host->{device_type}) or croak($dbh->errstr);
            while((my $graph = $selsth->fetchrow_hashref)) {
                push @graphs, $graph;
            }
            $selsth->finish;

            foreach my $graph (@graphs) {
                #my ($dbh, $graph, $table, $host, $ctime, $starttime) = @_;
                $reph->debuglog("  " . $host->{hostname} . " (" . $host->{device_type} . "): " . $graph->{graph_name} . " \@ $ctime");
                my $img = Maplat::Helpers::Logging::Graphs::genGraph($dbh, $graph, $host->{tablename}, $host->{hostname}, $ctime);
                if(!defined($img)) {
                    $reph->debuglog("Image creation failed!");
                    $dbh->rollback;
                    next;
                }
                if(!$delsth->execute($graph->{graph_name}, $host->{hostname}, $host->{device_type}, $ctime)) {
                    $reph->debuglog("Deletion of old image failed!");
                    $dbh->rollback;
                    next;
                }
                if(!$insth->execute($graph->{graph_name}, $host->{hostname}, $host->{device_type}, $ctime, dbfreeze(\$img))) {
                    $dbh->rollback;
                } else {
                    $dbh->commit;
                    $workCount++;
                }
                
                # Use less CPU power at once, sleep a second after each transaction:
                sleep(1);
                
                #my $fname = "tmp/img_" . $host . "_" . $graph->{graph_name} . "_" . $ctime . ".png";
                #open(my $fh, '>', $fname) or croak $!;
                #binmode $fh;
                #print $fh $img;
                #close $fh;
                
            }
        }
    }
    $reph->debuglog("$workCount graphs updated!");
    return $workCount;
}

1;
__END__

=head1 NAME

Maplat::Worker::Logging::Graphs - generate graphs with latest data in a background process

=head1 SYNOPSIS

  use Maplat::Worker;
  use Maplat::Worker::Logging;
  
Then configure() the module as you would normally.

=head1 DESCRIPTION

    <module>
        <modname>graphs</modname>
        <pm>Logging::Graphs</pm>
        <options>
            <db>maindb</db>
            <memcache>memcache</memcache>
            <reporting>reporting</reporting>
        </options>
    </module>

This module provides the webmasks required to configure logging devices.

=head2 work

Internal function, generates the graphs.

=head1 AUTHOR

Rene Schickbauer, E<lt>rene.schickbauer@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2010 by Rene Schickbauer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
