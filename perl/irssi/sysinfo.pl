use strict;
use warnings FATAL => qw(all);

use Irssi;

use Carp;

use POSIX qw(fmod WEXITSTATUS);

use CommonStuff;

sub program_exists($) {
	my ($prog) = @_;
	return WEXITSTATUS(system("which $prog >&/dev/null")) == 0;
}


sub get_cpu_data() {
	local $_;
	my @cpus;
	my $fd;
	my $curCPU = 0;
	open $fd, '<', '/proc/cpuinfo';
	while (<$fd>) {
		next unless m/^(.*?)\s*:\s*(.*?)\s*$/;
		my ($key, $value) = ($1, $2);
		if ($key eq "processor") {
			$curCPU = int($value);
			$cpus[$curCPU] = {};
		} elsif ($key eq "model name") {
			$cpus[$curCPU]->{'name'} = $value;
		} elsif ($key eq "cpu MHz") {
			$cpus[$curCPU]->{'speed'} = $value;
		}
	}
	close $fd;
	undef $fd;
	if (program_exists("cpufreq-info")) {
		for $curCPU (0..$#cpus) {
			my ($curFreq, $maxFreq);
			no warnings qw(numeric);
			$curFreq = int(qx|cpufreq-info --freq|);
			(undef, $maxFreq) = split(/\s+/, qx|cpufreq-info --policy|);
			unless ($curFreq == 0 || $maxFreq == 0) {
				$cpus[$curCPU]->{'scale current'} = $curFreq;
				$cpus[$curCPU]->{'scale maximum'} = $maxFreq;
			}
		}
	}
	return wantarray ? @cpus : \@cpus;
}

sub get_uptime_data() {
	local $_;
	my $fd;
	open $fd, '<', '/proc/uptime';
	my $line = <$fd>;
	close $fd;
	my ($data, undef) = split(/\s+/, $line);
	return $data;
}

sub get_load_data() {
	local $_;
	my $fd;
	open $fd, '<', '/proc/loadavg';
	my $line = <$fd>;
	close $fd;
	$line =~ m/^([0-9.]+) ([0-9.]+) ([0-9.]+) ([0-9.]+)\/([0-9.]+) [0-9.]+/;
	# $1 = Load 1min, $2 = Load 5min, $3 = Load 15min, $4 = Currently executing processes/threads, $5 = Total processes/threads, Not Captured: Last PID created
	my (@data) = ($1, $2, $3, $4, $5);
	return @data;
}

sub get_mem_data() {
	local $_;
	my %data;
	my $fd;
	open $fd, '<', '/proc/meminfo';
	my ($buf, $cache) = (0, 0);
	while (<$fd>)
	{
		if (/^MemTotal: +(\d+) kB/)
		{
			$data{'RAM Total'} = 1024*$1;
		}
		elsif (/^MemFree: +(\d+) kB/)
		{
			$data{'RAM Free'} = 1024*$1;
		}
		elsif (/^Buffers: +(\d+) kB/)
		{
			$buf = 1024*$1;
		}
		elsif (/^Cached: +(\d+) kB/)
		{
			$cache = 1024*$1;
		}
		elsif (/^SwapTotal: +(\d+) kB/)
		{
			$data{'Swap Total'} = 1024*$1;
		}
		elsif (/^SwapFree: +(\d+) kB/)
		{
			$data{'Swap Free'} = 1024*$1;
		}
	}
	close $fd;
	$data{'RAM Free'} += ($buf + $cache);
	$data{'RAM Used'} = ($data{'RAM Total'} - $data{'RAM Free'});
	$data{'Swap Used'} = ($data{'Swap Total'} - $data{'Swap Free'});
	open $fd, '<', '/proc/swaps';
	my $ary = [];
	while (<$fd>) {
		next unless m[^/];
		my ($filesystem, $type, $total, $used, $priority) = split(/\s+/, $_);
		push @$ary, {
			file => $filesystem,
			type => $type,
			total => $total,
			used => $used,
			priority => $priority,
		};
	}
	close $fd;
	$data{'Swap Sources'} = $ary;
	return \%data;
}

sub get_disk_data() {
	local $_;
	my @data;
	my $fd;
	open $fd, '-|', 'df -P -B 1 -T | grep ^/';
	while (<$fd>) {
		my ($device, $type, $total, $used, $avail, $usePercent, $mountPoint) = split(/\s+/, $_);
		my $deviceType = "";
		my $deviceNumber;
		(undef, undef, undef, undef, undef, undef, $deviceNumber) = stat($device);
		my ($options) = '';
		{
			my $mountFD;
			open $mountFD, '<', '/proc/mounts';
			while (<$mountFD>) {
				next unless m"^$device\s";
				(undef, undef, undef, $options) = split /\s+/, $_;
				last;
			}
			close $mountFD;
		}
		my ($devMajor, $devMinor) = (0, 0);
		if (!defined($deviceNumber)) {
			$deviceType = "Unstattable device/file ($!)";
		} else {
			($devMajor, $devMinor) = (($deviceNumber >> 8), ($deviceNumber & 0xFF));
			if ($deviceNumber == 0) {
				$deviceType = "Non-device";
			} else {
				if ($devMajor == 2) {
					$deviceType = "Floppy disk";
				} elsif ($devMajor == 3 || $devMajor == 22) {
					$deviceType = "IDE disk";
				} elsif ($devMajor == 8) {
					$deviceType = "External disk";
				} elsif ($devMajor == 9) {
					$deviceType = "External tape";
				} else {
					$deviceType = "Unknown device ($devMajor, $devMinor)";
				}
			}
		}
		push @data, {
			device => $device,
			'device type' => $deviceType,
			'device major' => $devMajor,
			'device minor' => $devMinor,
			filesystem => $type,
			total => $total,
			used => $used,
			available => $avail,
			'use%' => $usePercent,
			mount => $mountPoint,
			options => [ split /,/, $options ],
		};
	}
	close $fd;
	return wantarray ? @data : \@data;
}

sub trim($) {
	my ($string) = @_;
	$string =~ m/^\s*(.*?)\s*$/;
	return $1;
}

sub get_profile() {
	my $dir;
	my $prof;
	eval {
		if (defined($dir = readlink("/etc/make.profile"))) {
			if ($dir =~ m'^/usr/portage/profiles/(.*)/$') {
				$prof = $1;
			} else {
				$prof = $dir;
			}
		} else {
			$prof = "/etc/make.profile: $!";
		}
	};
	return ($@ ? "(no symlinks)" : $prof);
}

sub get_sys_info() {
	my %sysinfo = (
		'OS Info' => {
			distro => "Gentoo",
			kernel => trim(qx|uname --kernel-name|),
			profile => get_profile(),
			version => trim(qx|uname --kernel-release|),
		},
		Uptime => get_uptime_data(),
		Load => [get_load_data()],
		'CPU Info' => {
			arch => trim(qx|uname --machine|),
			cpus => [ get_cpu_data() ],
		},
		'Mem Info' => get_mem_data(),
		'Disk Info' => scalar(get_disk_data()),
	);
	return \%sysinfo;
}

sub format_metric($) {
	my ($amount) = @_;
	return "<nil>" unless defined($amount);
	my (@prefixes) = ( '', 'K', 'M', 'G', 'T' );
	my ($actual, $pow) = ($amount, 0);
	while (int($actual) >= 1000) {
		$actual /= 1000;
		++$pow;
	};
	if ($pow > $#prefixes) {
		return "$amount";
	} else {
		return sprintf("%.2f %s", $actual, $prefixes[$pow]);
	}
}

sub format_binary_metric($) {
	my ($amount) = @_;
	return "<nil>" unless defined($amount);
	my (@prefixes) = ( '', 'K', 'M', 'G', 'T' );
	my ($actual, $pow) = ($amount, 0);
	while (int($actual) >= 1024) {
		$actual /= 1024;
		++$pow;
	};
	if ($pow > $#prefixes || $pow <= 0) {
		return "$amount";
	} else {
		return sprintf("%.2f %s", $actual, $prefixes[$pow]);
	}
}

sub format_percent($$;$) {
	my ($amount, $outOf, $width) = @_;
	return "<nil>" unless defined($amount) && defined($outOf);
	my $percent = ($amount / $outOf);
	$width = 10 unless defined($width);
	if ($width >= 2) {
		return sprintf "[%-*s] (%.1f%%)", $width, '-' x int($width * $percent), 100 * $percent;
	} else {
		return sprintf "(%5.1f%%)", 100 * $percent;
	}
}

sub strip_dev ($) {
	my ($file) = @_;
	$file =~ s|^/dev/||;
	return $file;
}

sub append_string(\$$) {
	my ($to, $what) = @_;
	die "Need reference" unless ref($to) eq "SCALAR";
	if (length($$to) > 0) {
		$$to .= " | " . $what;
	} else {
		$$to = $what;
	}
	return $$to;
}

sub cmd_sysinfo {
	my ($data, $server, $witem) = @_;

	my @args = split /\s+/, $data;

	my $sendTo = 0;
	my ($doAll, $doOS, $doUp, $doLoad, $doScalingCPU, $doNonscaleCPU, $doRAM, $doSwap, $doSwaps, $doDisk) = (1, undef, undef, undef, undef, undef, undef, undef, undef, undef);
	while (scalar(@args) > 0) {
		local $_ = shift(@args);
		if ($_ eq '-o') {
			$sendTo = 1;
		} else {
			# OS Keywords:
			if (m/^(os|kernel)$/i) {
				($doAll, $doOS) = (undef, 1);
			}
			# Uptime keywords:
			elsif (m/^up(?:time)?$/i) {
				($doAll, $doUp) = (undef, 1);
			}
			elsif (m/^load(?:avg|average)?$/i) {
				($doAll, $doLoad) = (undef, 1);
			}
			# CPU Keywords:
			elsif (m/^cpu$/i) {
				($doAll, $doScalingCPU, $doNonscaleCPU) = (undef, 1, 1);
			}
			elsif (m/^noscale$/i) {
				($doAll, $doNonscaleCPU) = (undef, 1);
			}
			elsif (m/^scale$/i) {
				($doAll, $doScalingCPU) = (undef, 1);
			}
			# Memory Keywords:
			elsif (m/^mem(?:ory)?$/i) {
				($doAll, $doRAM, $doSwap, $doSwaps) = (undef, 1, 1, 1);
			}
			elsif (m/^RAM$/i) {
				($doAll, $doRAM) = (undef, 1);
			}
			elsif (m/^swap$/i) {
				($doAll, $doSwap) = (undef, 1);
			}
			elsif (m/^swaps$/i) {
				($doAll, $doSwaps) = (undef, 1);
			}
			# Disk Keywords:
			elsif (m/^disk$/i) {
				($doAll, $doDisk) = (undef, 1);
			}
			else {
				Irssi::signal_emit("error command", -3, $_); # Unknown option
				return;
			}
		}
	}

#	return;

	my $info = get_sys_info();

	my $osinfo = $info->{'OS Info'};
	my $cpuinfo = $info->{'CPU Info'};
	my $meminfo = $info->{'Mem Info'};
	my $diskinfo = $info->{'Disk Info'};
	my $netinfo = $info->{'Net Info'};

	my $str = "";

	if ($doAll || $doOS) {
		append_string($str, sprintf "OS: %s %s %s",
			$osinfo->{'distro'},
#			$osinfo->{'profile'},
			$osinfo->{'kernel'},
			$osinfo->{'version'},
#			$cpuinfo->{'arch'},
		);
	}

	if ($doAll || $doUp) {
		append_string($str, sprintf "Uptime: %s",
			format_duration($info->{Uptime}),
		);
	}

	if ($doAll || $doLoad) {
		my @load = @{$info->{Load}};
		append_string($str, sprintf "Load Averages: %.2f %.2f %.2f", $load[0], $load[1], $load[2]);
	}

	if ($doAll || $doScalingCPU || $doNonscaleCPU) {
		my $cpus = $cpuinfo->{'cpus'};
		for my $cpuIdx (0 .. $#$cpus) {
			my $cpu = $cpus->[$cpuIdx];
			if (exists($cpu->{'scale current'}) && exists($cpu->{'scale maximum'})) {
				next unless ($doAll || $doScalingCPU);
				append_string($str, sprintf "CPU%d: %s @ %sHz/%sHz %s",
					$cpuIdx,
					$cpu->{'name'},
					format_metric($cpu->{'scale current'} * 1000), # They come in KHz
					format_metric($cpu->{'scale maximum'} * 1000), # They come in KHz
					format_percent($cpu->{'scale current'}, $cpu->{'scale maximum'}, 0),
				);
			} else {
				next unless ($doAll || $doNonscaleCPU);
				append_string($str, sprintf "CPU%d: %s @ %sHz",
					$cpuIdx,
					$cpu->{'name'},
					format_metric($cpu->{'speed'} * 1000000),
				);
			}
		}
	}

	if ($doAll || $doRAM) {
		append_string($str, sprintf "RAM: %sB/%sB %s (%sB free)",
			format_binary_metric($meminfo->{'RAM Used'}),
			format_binary_metric($meminfo->{'RAM Total'}),
			format_percent($meminfo->{'RAM Used'}, $meminfo->{'RAM Total'}, 10),
			format_binary_metric($meminfo->{'RAM Free'}),
		);
	}


	if ($doAll || $doSwap) {
		append_string($str, sprintf "Swap: %sB/%sB %s",
			format_binary_metric($meminfo->{'Swap Used'}),
			format_binary_metric($meminfo->{'Swap Total'}),
			format_percent($meminfo->{'Swap Used'}, $meminfo->{'Swap Total'}, 10),
			format_binary_metric($meminfo->{'Swap Free'}),
		);
	}

	if ($doAll || $doSwaps) {
		my $swaps = $meminfo->{'Swap Sources'};
		for my $swapIdx (0 .. $#$swaps) {
			my $swap = $swaps->[$swapIdx];
			append_string($str, sprintf "Swap%d %s: %sB/%sB %s (%sB free)",
#				int(log(scalar(@$swaps))/log(10)) + 1,
				$swapIdx + 1,
				strip_dev($swap->{'file'}),
#				$swap->{'type'},
				format_binary_metric($swap->{'used'} * 1024), # They come in KB
				format_binary_metric($swap->{'total'} * 1024), # They come in KB
				format_percent($swap->{'used'}, $swap->{'total'}, 10),
				format_binary_metric(($swap->{'total'} - $swap->{'used'}) * 1024), # They come in KB
				$swap->{'priority'},
			);
		}
	}

	if ($doAll || $doDisk) {
		for my $diskIdx (0 .. $#$diskinfo) {
			my $disk = $diskinfo->[$diskIdx];
			append_string($str, sprintf '%s->%s %s %sB/%sB %s (%s)',
				strip_dev($disk->{device}),
				$disk->{mount},
#				$disk->{'device type'},
				$disk->{filesystem},
				format_binary_metric($disk->{used}),
				format_binary_metric($disk->{total}),
				format_percent($disk->{used}, $disk->{total}, 10),
				(scalar(grep { m/^ro$/ } @{$disk->{options}}) == 0 ? sprintf("%sB free", format_binary_metric($disk->{available})) : "readonly"),
			);
		}
	}

	if ($sendTo) {
		if (!$witem) {
			Irssi::signal_emit("error command", 5); # Not joined to any channel
			Irssi::print($str);
		} elsif (!$server) {
			Irssi::signal_emit("error command", 4); # Not joined to server
			Irssi::print($str);
		} else {
			while (length($str) > 450) {
				my $pipe = rindex($str, ' | ', 400);
				my $before = substr($str, 0, $pipe); # Up to, not incluing, the seperator.
				substr($str, 0, $pipe + 3) = ""; # Cut off the seperator too.
				$witem->command("say $before");
			}
			$witem->command("say $str");
		}
	} else {
		while (length($str) > 450) {
			my $pipe = rindex($str, ' | ', 400);
			my $before = substr($str, 0, $pipe); # Up to, not incluing, the seperator.
			substr($str, 0, $pipe + 3) = ""; # Cut off the seperator too.
			doprint($server, $witem, $before);
			doprint($server, $witem, sprintf("Length of line is %d", length($before)));
		}
		doprint($server, $witem, $str);
		doprint($server, $witem, sprintf("Length of line is %d", length($str)));
	}
}

Irssi::command_bind('sysinfo', 'cmd_sysinfo');
