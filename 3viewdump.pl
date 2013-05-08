#!/usr/bin/perl

use Net::UPnP::ControlPoint;
use Net::UPnP::AV::MediaServer;

#use Shell qw(ffmpeg);
#use Data::Dumper;

use File::Fetch;

#$Net::UPnP::DEBUG = 1;

#curl('--version');
#ffmpeg('-version');

#------------------------------
# program info
#------------------------------

$program_name = '3viewdump';
$copy_right = 'parts Copyright (c) 2005 Satoshi Konno';
$script_name = '3viewdump.pl';
$script_version = '0.4';

#------------------------------
# global variables
#------------------------------

@dms_content_list = ();

#------------------------------
# command option
#------------------------------

$base_directory = "./";
$rss_description = "RSS of 3view Programs";
$rss_link= "";
$rss_title = "3view RSS";
$requested_count = 0;
$rss_file = "";
$title_regexp = "";
$search_date = "";
$nopost = 0;
$File::Fetch::BLACKLIST = [qw|netftp curl wget|];
 
@command_opt = (
['-a', '--date', 'date string', 'The date string to parse for format yyyymmddhh_mm_ss'],
['-B', '--base-directory', '/path/to/', 'Set the base directory to output the RSS file and the MPEG4 files'],
['-d', '--rss-description', '<description>', 'Set the description tag in the output RSS file'],
['-h', '--help', '', 'This is help text.'],
['-l', '--rss-link', '<link>', 'Set the link tag in the output RSS file'],
['-n', '--nopost', '', 'Do not do any post-processing using ffmpeg (SD files only)'],
['-r', '--requested-count', '<number>', 'Set the max request count to the media server contents'],
['-t', '--rss-title', '<file>', 'Set the title tag in the output RSS file'],
['-f', '--rss-file', '<file>', 'RSS filename'],
['-s', '--search-title', '<regular expression>', 'Set the regular expression of the content titles by UTF-8'],
);

sub is_command_option {
	($opt) = @_;
	for ($n=0; $n<@command_opt; $n++) {
		if ($opt eq $command_opt[$n][0] || $opt eq $command_opt[$n][1]) {
			return $n;
		}
	}
	return -1;
}

#------------------------------
# main (parse command line)
#------------------------------

for ($i=0; $i<(@ARGV); $i++) {
	$opt = $ARGV[$i];
	$opt_num = is_command_option($opt);
	$opt_short_name = '';
	if ($opt_num < 0) {
		if ($opt =~ m/^-/) {
			print "$script_name : option $opt is unknown\n";
			print "$script_name : try \'$script_name --help\' for more information	\n";
			exit 1;
		}
	}
	else {
			$opt_short_name = $command_opt[$opt_num][0];
	}
	if ($opt_short_name eq '-h') {
		print "Usage : $script_name [options...] <output RSS file name>\n";
		print "Options : \n";
		$max_opt_output_len = 0;
		for ($n=0; $n<@command_opt; $n++) {
			$opt_output_len = length("$command_opt[$n][0]\/$command_opt[$n][1] $command_opt[$n][2]");
			if ($max_opt_output_len <= $opt_output_len) {
				$max_opt_output_len = $opt_output_len;
			}
		}
		for ($n=0; $n<@command_opt; $n++) {
			$opt_output_str = "$command_opt[$n][0]\/$command_opt[$n][1] $command_opt[$n][2]";
			print $opt_output_str;
			for ($j=0; $j<($max_opt_output_len-length($opt_output_str)); $j++) {
				print " ";
			}
			print " $command_opt[$n][3]\n";
		}
		exit 1;
	} elsif ($opt_short_name eq '-a') {
		$search_date = $ARGV[++$i];
	} elsif ($opt_short_name eq '-B') {
		$base_directory = $ARGV[++$i];
	} elsif ($opt_short_name eq '-d') {
		$rss_description = $ARGV[++$i];
	} elsif ($opt_short_name eq '-l') {
		$rss_link = $ARGV[++$i];
	} elsif ($opt_short_name eq '-n') {
		$nopost = 1;
	} elsif ($opt_short_name eq '-r') {
		$requested_count = $ARGV[++$i];
	} elsif ($opt_short_name eq '-t') {
		$rss_title = $ARGV[++$i];
	} elsif ($opt_short_name eq '-f') {
		$rss_file = $ARGV[++$i];
	} elsif ($opt_short_name eq '-s') {
		$title_regexp = $ARGV[++$i];
	} else {
		$rss_file_name = $opt;
	}
}

print "  $program_name (v$script_version), $copy_right\n";
print "  title : $rss_title\n";
print "  description : $rss_description\n";
print "  base directory : $base_directory\n";
print "  requested_count : $requested_count\n";
print "  rss file : $rss_file\n";
print "  search regexp : $title_regexp\n";

#------------------------------
# main
#------------------------------

my $obj = Net::UPnP::ControlPoint->new();

$retry_cnt = 0;
@dev_list = ();
#while (@dev_list <= 1 || $retry_cnt > 500) {
while ( $retry_cnt < 2) {
#	@dev_list = $obj->search(st =>'urn:schemas-upnp-org:device:MediaServer:1', mx => 10);
	@dev_list = $obj->search(st =>'upnp:rootdevice', mx => 3);
#	@dev_list = $obj->search();
	#print Dumper (@dev_list);
	print "$retry_cnt \n";
	$retry_cnt++;
} 

$devNum= 0;
foreach $dev (@dev_list) {
	#print Dumper $dev;
	$device_type = $dev->getdevicetype();
	#print "$device_type \n";
	#print "Device type is $device_type \n";
	#print Dumper $dev->getservicebyname('urn:schemas-upnp-org:service:ContentDirectory:1');
	#print "\n\n\n\n";
	#if  ($device_type ne 'urn:schemas-upnp-org:device:MediaServer:1') {
	if  ($device_type ne 'urn:schemas-upnp-org:device:Basic:1') {
		next;
	}
	unless ($dev->getservicebyname('urn:schemas-upnp-org:service:ContentDirectory:1')) {
		next;
	}
	print "[$devNum] : " . $dev->getfriendlyname() . "\n";
	#print Dumper($dev);
	$mediaServer = Net::UPnP::AV::MediaServer->new();
	$mediaServer->setdevice($dev);
	#@content_list = $mediaServer->getcontentlist(ObjectID => 0, RequestedCount => $requested_count);
	#The 'folders' presented by the 3view are represented by ObjectID, 0 will return the 3 top level directories
	#'Video' has an ObjectID of 2, 'Recorded Shows' is 21, 'By Title' is 211
	#@content_list = $mediaServer->getcontentlist(ObjectID => 21);
	#As of Feb 9th 2011, box returns title of show as date, do the title match here....
	@content_list = $mediaServer->getcontentlist(ObjectID => 211);
	#print "content_list = @content_list\n";
	foreach $content (@content_list) {
		my $act_tit = $content->{_title};
		#print "content $act_tit \n";
		if ($act_tit =~ m/$title_regexp/){
		#if ( (length($title_regexp) == 0) || ($act_tit =~ m/$title_regexp/) ){
			#print "I get here!\n";
			#print Dumper $content;
			parse_content_directory( $act_tit, $mediaServer, $content);
		}
	}

	$devNum++;
}
if (length($rss_file) > 0 ) {
	make_rss(@dms_content_list);
}
exit 0;

#------------------------------
# Output RSS file
#------------------------------
sub make_rss {

	@rss_content_list = @_;
	if ( @rss_content_list <= 0 ) {	
		print "Couldn't find video contents !!\n";
		exit 1;
	}

	$output_rss_filename = $base_directory . $rss_file;

	open(RSS_FILE, ">$output_rss_filename") || die "Couldn't open the specifed output file($output_rss_filename)\n";

	$rss_header = <<"RSS_HEADER";
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:itunes="http://www.itunes.com/DTDs/Podcast-1.0.dtd" version="2.0">
<channel>
<title>$rss_title</title>
<description>$rss_description</description>
<link>$rss_link</link>
RSS_HEADER
	print RSS_FILE $rss_header;

	foreach $content (@rss_content_list){
		$title = $content->{'title'};	
		$fname = $content->{'file_name'};
		#$fsize = $content->{'file_size'};
		$ulink = $content->{'file_url'};
		$umime = $content->{'file_mime'};

	$mp4_link = $ulink;
	$mp4_item = <<"RSS_MP4_ITEM";
<item>
<title>$title</title>
<guid isPermalink="false">$mp4_link</guid>
<enclosure url="$mp4_link" type="$umime" />
</item>
RSS_MP4_ITEM
		print RSS_FILE $mp4_item;
	}

	$rss_footer = <<"RSS_FOOTER";
</channel>
</rss>
RSS_FOOTER
	print RSS_FILE $rss_footer;

	close(RSS_FILE);

	$rss_outputted_items = @rss_content_list;
	print "Outputted $rss_outputted_items RSS items to $output_rss_filename\n";
}

#------------------------------
# parse_content_directory
#------------------------------

sub parse_content_directory {
	my $act_tit = shift;
	print "$act_tit whatup \n";
	( $mediaServer, $content) = @_;

	my $objid = $content->getid();

	if ($content->isitem()) {
		#my $title = $content->gettitle();
		#my $title = $content->{_title};
		#$title =~ tr/a-zA-Z0-9/_/cd;
		#my $date = ParseDate($content->{_date});
		my $date = $content->{_date};
		$date =~ tr/0-9//cd;
		my $mime = $content->{_contenttype};
		print "mime is: $mime ";
		if ($mime =~ m/video/) {
			if ((length($search_date) == 0) || ($date =~ m/$search_date/)) {
				#print "title: $title ";
				print "mime: $mime ";
				print "date: $date search_date $search_date\n";
				#print Dumper $content;
				#print Dumper $mediaServer->browsemetadata($objid);
				my $dms_content_count = @dms_content_list;
				if ($requested_count == 0 || $dms_content_count < $requested_count) {
					my $mp4_content = get_content($act_tit, $mediaServer, $content);
					if (defined($mp4_content)) {
						push(@dms_content_list, $mp4_content);
					}
				}
			}
		}
	}
	
	unless ($content->iscontainer()) {
		return;
	}

	my @child_content_list = $mediaServer->getcontentlist(ObjectID => $objid );
	
	if (@child_content_list <= 0) {
		return;
	}
	
	foreach my $child_content (@child_content_list) {
		parse_content_directory( $act_tit, $mediaServer, $child_content);
	}
}

#------------------------------
# get_content
#------------------------------

sub get_content {
	($act_tit, $mediaServer, $content) = @_;
	my $objid = $content->getid();
	#my $title = $content->gettitle();
	$act_tit =~ tr/a-zA-Z0-9/_/c;
	my $date = $content->{_date};
	$date =~ tr/0-9//cd;

	my $url = $content->geturl();
	my $mime = $content->{_contenttype};
	
	print "[$objid] $act_tit date: $date ($url)\n";
	
	my $dev = $mediaServer->getdevice();
	my $dev_friendlyname = $dev->getfriendlyname();
	#print "dev_friendly_name $dev_friendlyname\n";
	my $dev_udn = $dev->getudn();
	$dev_udn =~ s/:/-/g;
	
	my $filename_body = $act_tit . "_" . $date;
	$filename_body =~ s/ //g;
	$filename_body =~ s/\//-/g;
	
	my $post_file_name;
	my $acodec_option;
	my $output_file_name = $base_directory . $filename_body . ".mp4";

	if ((!(-e $output_file_name))&&($rss_file eq "")) {	
		my $ff = File::Fetch->new( uri => $url );
		my $raw_file_name = $ff->fetch();
		if ($nopost) {
			rename $raw_file_name, $output_file_name;
		} else {
			if ( isitHD($content)) {
				$ffmpeg_opt = "nice ffmpeg -y -i \"$raw_file_name\" -acodec libfaac -ac 2 -ab 128k -vcodec copy \"$output_file_name\"";
			} else {
				$ffmpeg_opt = "nice ffmpeg -y -i \"$raw_file_name\" -vcodec libx264 -preset slow -b:v 755k -pass 1 -an -f mp4 /dev/null && nice ffmpeg -i \"$raw_file_name\" -vcodec libx264 -preset slow -b:v 755k -pass 2 -c:a libfaac -b:a 128k \"$output_file_name\"";
			}
			print "$ffmpeg_opt\n";
			system($ffmpeg_opt);
			unlink($raw_file_name);
		}
	}
		
	my %info = (
		'objid'     => $objid,
		'title'     => "$filename_body",
		'file_name' => $post_file_name,
		#'file_size' => $post_file_size,
		'file_url'  => $url,
		'file_mime' => $mime,
	);
	
	return \%info;
}

#------------------------------
# is it HD
#------------------------------
sub isitHD {
	#returns 1 if it is HD
	my $hdcontent = shift;
	my $urlre = 'cofdm_8k-';
	my $url = $hdcontent->geturl();
	if ( $url =~ m/$urlre/ ) {
		return 1;
	} else {
		return 0;
	}
}


