# MAPLAT  (C) 2008-2010 Rene Schickbauer
# Developed under Artistic license
# for Magna Powertrain Ilz
package Maplat::Worker::Logging::PAC3200;
use strict;
use warnings;

use base qw(Maplat::Worker::BaseModule);

use WWW::Mechanize;
use HTML::TableExtract;
use Net::Ping;
use IO::Socket;
use Carp;
use Readonly;

our $VERSION = 0.993;

Readonly my $MAX_RECV_LEN => 65536;

# Defaults for SENTRON PAC3200
my %mess = (
    out_voltage1    => 1,
    out_voltage2    => 3,
    out_voltage3    => 5,
    in_voltage1     => 7,
    in_voltage2     => 9,
    in_voltage3     => 11,
    out_current1    => 13,
    out_current2    => 15,
    out_current3    => 17,
    out_power1      => 25,
    out_power2      => 27,
    out_power3      => 29,
    power_apparent    => 63,
    power_active    => 65,
    power_idle        => 67,
    power_factor    => 69,
    max_current1    => 87,
    max_current2    => 89,
    max_current3    => 91,
    operating_hours    => 213,
    #powersum_active    => 801,
);

my %units = (
    voltage => "V",
    current => "A",
    power   => "W",
    load    => '%',
    hours   => "h",
    used    => "Wh",
    apparent => 'VA',
    active    => 'W',
    idle    => 'var',
    factor    => '%',
);


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
    
    my $dbh = $self->{server}->{modules}->{$self->{db}};
    my $reph = $self->{server}->{modules}->{$self->{reporting}};
    my $memh = $self->{server}->{modules}->{$self->{memcache}};
	# Refresh Lifetick every now and then
	$memh->refresh_lifetick;

    
    my @todo;
    my $selstmt = "SELECT * FROM logging_devices
                    WHERE device_type = 'PAC3200'
                    AND is_active = 't'
                    AND scanspeed = '" . $self->{scanspeed} . "'
                    ORDER BY hostname";
    my $selsth = $dbh->prepare_cached($selstmt)
            or croak($dbh->errstr);
    $selsth->execute or croak($dbh->errstr);
    while((my $device = $selsth->fetchrow_hashref)) {
        push @todo, $device;
    }
    $selsth->finish;

    my @offsets;
    foreach my $key (sort keys %mess) {
        push @offsets, $mess{$key};
    }

    
    foreach my $device (@todo) {
        $reph->debuglog("Logging PAC3200 for " . $device->{hostname} . " at " . $device->{ip_addr});
		# Refresh Lifetick every now and then
		$memh->refresh_lifetick;

        my @floats;
        if($self->getData($device->{ip_addr}, 502, \@floats, @offsets)) {

            my %data;
            foreach my $key (sort keys %mess) {
                my $val = @floats[$mess{$key}];
                
                # Check for some out-of-boundary values
                if($val =~ /QNAN/io) {
                    $val = 0;
                }
                
                # Convert to correct data type
                if($key =~ /(load)/) {
                    $val = int($val * 100);
                } elsif($key !~ /(current|temp)/) {
                    $val = int($val);
                } elsif($key =~ /operating_hours/) {
                    $val = int($val/3600);
                } else {
                    $val = int($val * 10) / 10;
                }
                
                $data{$key} = $val;
            }
            
            $data{hostname} = $device->{hostname};
            $data{device_type} = 'PAC3200';
            my ($keys, $vals) = ("", "");
            foreach my $key (sort keys %data) {
                $keys .= ",$key";
                if($key eq "hostname" || $key eq "bat_status" || $key eq "device_type") {
                    $vals .= "," . $dbh->quote($data{$key});
                } else {
                    $vals .= "," . $data{$key};
                }
            }
            $keys =~ s/^\,//o;
            $vals =~ s/^\,//o;
            my $instmt = "INSERT INTO logging_log_pac3200 ($keys) VALUES ($vals)";
            my $insth = $dbh->prepare($instmt) or croak($dbh->errstr);
            $insth->execute or croak($dbh->errstr);
            $insth->finish;
            $dbh->commit;
        } else {
            $reph->debuglog("Access failed to " . $device->{hostname} . "!");
            my $errorstmt = "INSERT INTO logging_log_pac3200 (hostname, device_type, device_ok)
                            VALUES (" . $dbh->quote($device->{hostname}) . ", 'PAC3200', 'f')";
            my $errorsth = $dbh->prepare($errorstmt) or croak($dbh->errstr);
            $errorsth->execute or croak($dbh->errstr);
            $errorsth->finish;
            $dbh->commit;            
        }
    }
    $dbh->rollback;
    return;
}

sub getData {
    my ($self, $host, $port, $floats, @offsets) = @_;
    
    # First of all, try to ping the device
    my $p = Net::Ping->new("icmp", 3); # 3 second timeout
    return unless $p->ping($host);

    my $trans_serv = getprotobyname( 'tcp' );
    my $remote_host = gethostbyname( $host );
    my $destination = sockaddr_in( $port, $remote_host );
      
    socket( TCP_SOCK, PF_INET, SOCK_STREAM, $trans_serv )
        or return;
    my $con_ok = connect( TCP_SOCK, $destination )
        or return;
    return unless $con_ok;

                
    my $data;
    foreach my $offset (@offsets) {
        my $command = $self->makeCMD("00 00 00 00 00 06 02 04 00 01 00 04", $offset);
        my @rawvals;
        
        send( TCP_SOCK, $command, 0 )
                or return;
    
        my $from_who = recv( TCP_SOCK, $data, $MAX_RECV_LEN, 0 );

        if ( $from_who ){                                     #New data from server   
            my ( $the_port, $the_ip ) = sockaddr_in( $destination );
            for (my $i = 0; $i < (length( $data ) - 9)/2;$i++){
                my $hex = substr $data, $i*2+9, 2;
                $hex = unpack "H*", $hex;
                my  $regadd = 0  + $i;
                #print " $regadd : [$hex] \n";
                push @rawvals, $hex;
            }
        } else {
            return;
        }
        shift @rawvals;
        my $realval;
        if($offset == 213) {
            # FIXME!!! QUICKHACK FOR THE ONE UNSIGNED LONG WE NEED
            $realval = $self->decode(\@rawvals, 1, 'V');
            $realval = int($realval/3600);
        } elsif($offset == 801) {
            # FIXME!!! QUICKHACK FOR THE ONE DOUBLE WE NEED
            $realval = $self->decode(\@rawvals, 1, 'd');
        } else {
            $realval = $self->decode(\@rawvals, 1, 'f');
        }
        $floats->[$offset] = $realval;
    }
    
    shutdown( TCP_SOCK, 2 );
    return 1;
}

sub decode {
    my ($self, $rawvals, $offset, $type) = @_;
    
    #print "Offset: $offset\n";
    my $str = $rawvals->[$offset] . $rawvals->[$offset + 1];
    my $val = unpack $type, reverse pack "H*", $str;
    
    return $val;
}


sub makeCMD {    
    my ($self, $str, $offset) = @_;
    
    my @cmd;
    my @parts = split/\ /, $str;
    
    $offset -= 2;
    if($offset < 1) {
        $offset = 1;
    }
    
    my $tmp = sprintf("%04x", $offset);
    $tmp =~ /(..)(..)/;
    my ($high, $low) = ($1, $2);
    $parts[8] = $high;
    $parts[9] = $low;
    
    foreach my $part (@parts) {
        #print "$part = ";
        my ($high, $low) = split//,$part;
        my $val = hex $part;
        #print "$val\n";
        push @cmd, chr($val);
    }
    my $cmdstring = join('', @cmd);
    return $cmdstring;
}

1;
__END__

=head1 NAME

Maplat::Worker::Logging::PAC3200 - Log from PAC3200 electricity meter

=head1 SYNOPSIS

  use Maplat::Worker;
  use Maplat::Worker::Logging;
  
Then configure() the module as you would normally.

=head1 DESCRIPTION

    <module>
        <modname>pac3200</modname>
        <pm>Logging::PAC3200</pm>
        <options>
            <db>maindb</db>
            <memcache>memcache</memcache>
            <reporting>reporting</reporting>
            <scanspeed>fast</scanspeed>
        </options>
    </module>

This module provides the webmasks required to configure logging devices.

=head2 work

Internal function, logs for all PAC3200 devices.

=head2 decode

Internal function.

=head2 getData

Internal function.

=head2 makeCMD

Internal function.

=head1 AUTHOR

Rene Schickbauer, E<lt>rene.schickbauer@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2010 by Rene Schickbauer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
