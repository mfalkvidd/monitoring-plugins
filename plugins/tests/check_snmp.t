#! /usr/bin/perl -w -I ..
#
# Test check_snmp by having an actual SNMP agent running
#

use strict;
use Test::More;
use NPTest;
use FindBin qw($Bin);

# Check that all dependent modules are available
eval {
	require NetSNMP::OID;
	require NetSNMP::agent;
	require NetSNMP::ASN;
};

if ($@) {
	plan skip_all => "Missing required module for test: $@";
}

my $port_snmp = 16100 + int(rand(100));


# Start up server
my @pids;
my $pid = fork();
if ($pid) {
	# Parent
	push @pids, $pid;
	# give our agent some time to startup
	sleep(1);
} else {
	# Child
	#print "child\n";

	print "Please contact SNMP at: $port_snmp\n";
	close(STDERR); # Coment out to debug snmpd problems (most errors sent there are OK)
	exec("snmpd -c tests/conf/snmpd.conf -C -f -r udp:$port_snmp");
}

END { 
	foreach my $pid (@pids) {
		if ($pid) { print "Killing $pid\n"; kill "INT", $pid } 
	}
};

if ($ARGV[0] && $ARGV[0] eq "-d") {
	while (1) {
		sleep 100;
	}
}

my $tests = 9;
if (-x "./check_snmp") {
	plan tests => $tests;
} else {
	plan skip_all => "No check_snmp compiled";
}

my $res;

$res = NPTest->testCmd( "./check_snmp -H 127.0.0.1 -C public -p $port_snmp -o .1.3.6.1.4.1.8072.3.2.67.0");
cmp_ok( $res->return_code, '==', 0, "Exit OK when querying a multi-line string" );
like($res->output, '/^SNMP OK - /', "String contains SNMP OK");
like($res->output, '/'.quotemeta('SNMP OK - Cisco Internetwork Operating System Software | 
.1.3.6.1.4.1.8072.3.2.67.0:
"Cisco Internetwork Operating System Software
IOS (tm) Catalyst 4000 \"L3\" Switch Software (cat4000-I9K91S-M), Version
12.2(20)EWA, RELEASE SOFTWARE (fc1)
Technical Support: http://www.cisco.com/techsupport
Copyright (c) 1986-2004 by cisco Systems, Inc.
"').'/m', "String contains all lines");

# sysContact.0 is "Alice" (from our snmpd.conf)
$res = NPTest->testCmd( "./check_snmp -H 127.0.0.1 -C public -p $port_snmp -o .1.3.6.1.4.1.8072.3.2.67.0 -o sysContact.0 -o .1.3.6.1.4.1.8072.3.2.67.1");
cmp_ok( $res->return_code, '==', 0, "Exit OK when querying multi-line OIDs" );
like($res->output, '/^SNMP OK - /', "String contains SNMP OK");
like($res->output, '/'.quotemeta('SNMP OK - Cisco Internetwork Operating System Software Alice Kisco Outernetwork Oserating Gystem Totware | 
.1.3.6.1.4.1.8072.3.2.67.0:
"Cisco Internetwork Operating System Software
IOS (tm) Catalyst 4000 \"L3\" Switch Software (cat4000-I9K91S-M), Version
12.2(20)EWA, RELEASE SOFTWARE (fc1)
Technical Support: http://www.cisco.com/techsupport
Copyright (c) 1986-2004 by cisco Systems, Inc.
"
.1.3.6.1.4.1.8072.3.2.67.1:
"Kisco Outernetwork Oserating Gystem Totware
Copyleft (c) 2400-2689 by kisco Systrems, Inc."').'/m', "String contains all lines with multiple OIDs");

$res = NPTest->testCmd( "./check_snmp -H 127.0.0.1 -C public -p $port_snmp -o .1.3.6.1.4.1.8072.3.2.67.2");
like($res->output, '/'.quotemeta('SNMP OK - This should not confuse check_snmp \"parser\" | 
.1.3.6.1.4.1.8072.3.2.67.2:
"This should not confuse check_snmp \"parser\"
into thinking there is no 2nd line"').'/m', "Attempt to confuse parser No.1");

$res = NPTest->testCmd( "./check_snmp -H 127.0.0.1 -C public -p $port_snmp -o .1.3.6.1.4.1.8072.3.2.67.3");
like($res->output, '/'.quotemeta('SNMP OK - It\'s getting even harder if the line | 
.1.3.6.1.4.1.8072.3.2.67.3:
"It\'s getting even harder if the line
ends with with this: C:\\\\"').'/m', "Attempt to confuse parser No.2");

$res = NPTest->testCmd( "./check_snmp -H 127.0.0.1 -C public -p $port_snmp -o .1.3.6.1.4.1.8072.3.2.67.4");
like($res->output, '/'.quotemeta('SNMP OK - And now have fun with with this: \"C:\\\\\" | 
.1.3.6.1.4.1.8072.3.2.67.4:
"And now have fun with with this: \"C:\\\\\"
because we\'re not done yet!"').'/m', "Attempt to confuse parser No.3");
