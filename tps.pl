#!/router/bin/perl -w
use strict;
use warnings;

use lib qw(./perllib);
use Text::CSV;
use CGI::Pretty qw(:standard escapeHTML);
use Time::Local;
use DateTime;

our (
	%caseStatus,
	%caseGroup,
	%caseAssignee,
	%caseReportDate,
	%caseReportDateUnix,
	%caseBucket,
	$supportGroupHeader,
	%XferCases,
	%ResCases
);

#times in seconds
my $time12hr = 43200;
my $time24hr = 86400;
my $time48hr = 172800;
my $time168hr = 604800;



#my $FILE = 'reports/TPS-Report_2012-08-23-13-40-43.CSV';
my @reportFiles = <reports/*>;
my $FILE = $reportFiles[$#reportFiles];



my $filterAG = param('filterAG');
my $now = time(); #unix timestamp

my $csv = Text::CSV->new();

open (CSV, "<", $FILE) or die $!;

while (<CSV>) {
	next if ($. == 1);
	if ($csv->parse($_)) {
		my @columns = $csv->fields();
		my $caseID = $columns[0];
		$caseStatus{$caseID} = $columns[1];
		$caseGroup{$caseID} = $columns[2];
		$caseAssignee{$caseID} = $columns[3];
		$caseReportDate{$caseID} = $columns[4];
		$caseReportDateUnix{$caseID} = $columns[5];
	} else {
		my $err = $csv->error_input;
		print "Failed to parse line: $err";
	}
}

foreach my $caseID (sort keys %caseStatus) {
	my $caseAge = $now - $caseReportDateUnix{$caseID};
	my $bucketID;
	if ($caseAssignee{$caseID} eq '') {
		#XferCases cases first
		#initialize XferCases group buckets if needed
		for (0..4) {
			if (!(defined($XferCases{$caseGroup{$caseID}}[$_]))) {
				$XferCases{$caseGroup{$caseID}}[$_] = ''
			}
		}
		#sort into buckets
		if ($caseAge < $time12hr) {
			$bucketID = 0;
		} elsif (($caseAge >= $time12hr) and ($caseAge < $time24hr)) {
			$bucketID = 1;
		} elsif (($caseAge >= $time24hr) and ($caseAge < $time48hr)) {
			$bucketID = 2;
		} elsif (($caseAge >= $time48hr) and ($caseAge < $time168hr)) {
			$bucketID = 3;
		} else {
			$bucketID = 4;
		}
		if ($XferCases{$caseGroup{$caseID}}[$bucketID] eq '') {
			$XferCases{$caseGroup{$caseID}}[$bucketID] = 1;
		} else {
			$XferCases{$caseGroup{$caseID}}[$bucketID] += 1;
		}
		$caseBucket{$caseID} = $bucketID;
	} else {
		#Now ResCases
		#initialize ResCases group buckets if needed
		for (0..4) {
			if (!(defined($ResCases{$caseGroup{$caseID}}[$_]))) {
				$ResCases{$caseGroup{$caseID}}[$_] = ''
			}
		}
		#sort into buckets
		if ($caseAge < $time12hr) {
			$bucketID = 0;
		} elsif (($caseAge >= $time12hr) and ($caseAge < $time24hr)) {
			$bucketID = 1;
		} elsif (($caseAge >= $time24hr) and ($caseAge < $time48hr)) {
			$bucketID = 2;
		} elsif (($caseAge >= $time48hr) and ($caseAge < $time168hr)) {
			$bucketID = 3;
		} else {
			$bucketID = 4;
		}
		if ($ResCases{$caseGroup{$caseID}}[$bucketID] eq '') {
			$ResCases{$caseGroup{$caseID}}[$bucketID] = 1;
		} else {
			$ResCases{$caseGroup{$caseID}}[$bucketID] += 1;
		}
		$caseBucket{$caseID} = $bucketID;
	}
}



my $reportTimestamp = $FILE;
$reportTimestamp =~ s/reports\/TPS-Report_(.*)\.CSV/$1/;
my @reportTime = split('-', $reportTimestamp);
# [0] = year
# [1] = month
# [2] = day
# [3] = hour
# [4] = min
# [5] = sec

my $dt = DateTime->from_epoch( epoch=> $now , time_zone => "America/New_York");
my $nowTimestamp = $dt->mdy('/') . " " . $dt->hms;

print header();
print start_html(-title=>"TPS - Time Prioritized Service-requests");

print h1("Time Prioritized Service-Request (TPS) Report");

print table (
	Tr (
		td("Time of report:"),
		td("$reportTime[1]/$reportTime[2]/$reportTime[0] $reportTime[3]:$reportTime[4]:$reportTime[5]")
	),
	Tr (
		td("Current time:"),
		td("$nowTimestamp")
	)
);

if ($filterAG) {
	$supportGroupHeader = th( "Support Group (", a({href=>"tps.pl"},"all"), ")");
} else {
	$supportGroupHeader = th("Support Group");
}

my @trs;
foreach my $group (sort keys %XferCases) {
	my @tds;
	my $total=0;
	next if (($filterAG) and ($group ne $filterAG));
	push @tds, td(a({href=>"tps.pl?filterAG=$group"},$group));
	for (0..4) {
		push @tds, td({align=>"center"}, $XferCases{$group}[$_]);
		$total += $XferCases{$group}[$_];
	}
	push @tds, td({align=>"center"}, strong($total));
	push @trs, Tr(@tds);
}

print p(strong("Unassigned Cases (dispatch within 24 hours)"));
print table({border=>"1"},
	Tr (
		th("Support Group"),
		th("0-12"),
		th("12-24"),
		th("24-48"),
		th("48-168"),
		th("168-older"),
		th("Total")
	),
	@trs
);

undef @trs;
foreach my $group (sort keys %ResCases) {
	my @tds;
	my $total=0;
	next if (($filterAG) and ($group ne $filterAG));
	push @tds, td(a({href=>"tps.pl?filterAG=$group"},$group));
	for (0..4) {
		push @tds, td({align=>"center"}, $ResCases{$group}[$_]);
		$total += $ResCases{$group}[$_];
	}
	push @tds, td({align=>"center"}, strong($total));
	push @trs, Tr(@tds);
}

print p(strong("Assigned Cases (resolve within 48 hours)"));
print table({border=>"1"},
	Tr (
		th("Support Group"),
		th("0-12"),
		th("12-24"),
		th("24-48"),
		th("48-168"),
		th("168-older"),
		th("Total")
	),
	@trs
);


if ($filterAG) {
	undef @trs;
	foreach my $caseID (sort keys %caseStatus) {
		my @tds;
		next if (($filterAG) and ($caseGroup{$caseID} ne $filterAG));
		push @tds, td($caseID);
		push @tds, td($caseStatus{$caseID});
		push @tds, td(a({href=>"tps.pl?filterAG=$caseGroup{$caseID}"},$caseGroup{$caseID}));
		push @tds, td($caseAssignee{$caseID});
		push @tds, td($caseReportDate{$caseID});
		push @tds, td($caseReportDateUnix{$caseID});
		
		push @trs, Tr(@tds);
	}

	print table({border=>"1"},
		Tr(
			th("CaseID"),
			th("Status"),
			$supportGroupHeader,
			th("Assignee"),
			th("Report Date (PDT)"),
			th("Report Date (Unix)")
		),
		@trs
	);
}

print end_html();

close CSV;
