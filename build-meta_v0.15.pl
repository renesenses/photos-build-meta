#!/usr/bin/perl -w

# v0.15 copying to target whatever it is

use File::Compare;
use File::Basename;
use File::Path;
use File::Spec;
use File::Copy;
use File::Find;

# use strict;

my $nb_read 			= 0;
my $nb_icloud 			= 0;
my $nb_scans_in_error 	= 0;
my $nb_files_copied 	= 0;
my $nb_files_v 			= 0;
my $nb_total 			= 0;

my $dim_home;

my $target_file;
my $target_dir;

my $BACKUP_VOLUME 				= "/Volumes/DIAPOS/";
#my $BACKUP_DIR 					= "";

my $ICLOUD_DIR					= "ICLOUD";
my $ERROR_DIR 					= "ERROR_META";
my $OTHER_DIR					= "V_META";

# my $REL_PICTURES_STEP_1_DIR 	= "/TEST/SCANS";
# my $REL_PICTURES_STEP_2_DIR 	= "/MINOLTA/TEST";
my $REL_PICTURES_STEP_2_DIR 	= "META";

### SUB ###

# With $var instead

sub mount_volume {
	my $volume = $_[0];
	my $cmd = `mount -t smbfs //192.168.1.58/BACKUP $BACKUP_VOLUME`;
}

sub file_exists {
	my $vol = $_[0]; 
	if (-e($vol)) {
		return 1;
	}
	else {
		return 0;
	}
}

sub get_file_extension {
	my $fullname = $_[0];
	my ($file,$dir,$ext) = fileparse($fullname, qr/\.[^.]*/);
	if ($ext eq "") {
		return $ext;
	}
	else {
		return substr($ext,1);
	}
}

sub print_nb_scans {
	print "PRINTING SCANS_FILES and nb_scans \n";
	foreach my $file (sort keys %SCANS_FILES) {
		print "\t DIR \t [ ",$file," ] \n";
	}
}

sub print_SCANS_FILES {
	print "PRINTING SCANS_FILES \n";
	foreach my $file (keys %SCANS_FILES) {
		print "\t FILE \t [ ",$file,	"\t",$SCANS_FILES{$file}{dir_type},
									"\t",$SCANS_FILES{$file}{dir_year},
									"\t",$SCANS_FILES{$file}{dir_event},
						" ] \n";
	}
}

# Called by File::Find and do not backup hidden files

# scans_dir : SCANS
# image_dir : META

# HASH SCANS_FILES : {dir_name}, nb_scans

sub read_diapos {

	my $dir_type;
	my $dir_name;
#	my @file_error_array;
	my $file_name;
	my $dir_event;
	my $dir_year;
	my $nulldir;
	my $file_extension;
	my $file_sequence;
	my $file_version;
	my $error_status;
	my $file_begin;	
	my $file_name_id;
	my $dir_dim;
		
	if ( !($_ =~ /^\./) ) {
#		print "ENTRY : ",$File::Find::name,"\n";
		if ( -f $_ ) {
			$file_sequence =0;
			$file_version =0;
			$error_status =0;
#			print "FILE : ",$File::Find::name,"\n";
			$nb_read++;
			my @dirs = File::Spec->splitdir($File::Find::name);
			$dir_dim = $#dirs;
#			print "DIRS : ",join("/",@dirs),"\n"; 
			
			($file_name,my $d,my $e)	= fileparse(pop(@dirs),qr/\.[^.]*/);
			$file_extension 			= get_file_extension($File::Find::name);
			
			$dir_event			= pop(@dirs);
			$dir_year			= pop(@dirs);
			$dir_type			= pop(@dirs);
		
		# REGEX NOT DESIGNED SO USING A SET OF NASTY IFs 	
		# MATCHING THE REGEX
		# TEMPLATE : /^([0-9]){4})_(A-STRING)_([0-9]){3})?_v([0-9]){3})$/
		
			if ( $file_name =~ /_([0-9]{3})(_v([0-9]{3}))?$/ ) {
				$error_status = 0;
				if (defined($1)) {
#					$file_begin = ${^PREMATCH};
					$file_begin = $`;
					$file_sequence = $1 +0; # chaine de 3 caractères forced in int
					if ( defined($3) ) { 
						$file_version = $3 +0; # chaine de 3 caractères forced in int
					}
				}
			}	
			
		$dir_name = File::Spec->catdir($dir_year,$dir_event);

			
		my $rec;
			$rec->{file_begin} 			= $file_begin;
			$rec->{dir_name} 			= $dir_name;
			$rec->{dir_dim} 			= $dir_dim;
			$rec->{dir_event} 			= $dir_event;
			$rec->{dir_year} 			= $dir_year;
			$rec->{dir_type} 			= $dir_type;
			$rec->{file_extension} 		= $file_extension;
			$rec->{file_sequence} 		= $file_sequence;

			$rec->{file_version} 		= $file_version;
			$rec->{file_name} 			= $file_name;
			$rec->{error_status} 		= $error_status;
			$rec->{errors_list} 		= [];
			$rec->{new_filename}		= "";
			$rec->{filename_id}			= $File::Find::name;

#			print "FILE_NAME : ",$rec->{file_name}, "\t |";
#			print "BEGIN : ",$rec->{file_begin}, "\t |";
#			print "DIR_NAME : ",$rec->{dir_name}, "\t |";
#			print "DIR_DIM : ",$rec->{dir_dim}, "\t |";
#			print "DIR_EVENT : ",$rec->{dir_event}, "\t |";
#			print "DIR_YEAR : ",$rec->{dir_year}, "\t |";
#			print "DIR_TYPE : ",$rec->{dir_type}, "\t |";						
#			print "FILE_EXT : ",$rec->{file_extension},  "\t |";	
#			print "FILE_SEQUENCE : ",$rec->{file_sequence}, "\t |" ;	
#			print "FILE_VERSION : ",$rec->{file_version}, "\n";	
#			print "\n";
			
			$SCANS_FILES{ $rec->{filename_id} } = $rec;

		}
	}
}


sub check_diapos {
	print "CHECK DIAPOS \n";
# FOR INITIAL DELIVERY, ONLY WE DEAL ONLY WITH THE FOLLOWING ERORS :
# FILENAME_ID Must not contain _vDDD
# (FILE _NAME, SEQUENCE, greater _vDDD if any 
#- ERR-NULL-VALUE 


#	compute and set the new filename before moving ($ERROR_DIR or $ICLOUD_DIR 
# FIELDS 
# 	{filename_id}	: [ERR-YEAR-DIR, ERR-DIR-EVENT,  ]
# 	{dir_name}		: [NONE]:
#	{dir_event}		: [ERR-EVENT-FORMAT]
#	{dir_year}		: [ERR-YEAR-FORMAT]
#	{dir_type}		: [ERR-DIR-TYPE-NAME]
#	{file_extension}: [ERR-NOT-IMG-FORMAT]
#	{file_sequence}	: [ERR-NOT-LAST, ERR-NULL-VALUE]
#	{file_version}	: [ ]
#	{file_name}		: [idem filename_id]
#	{error_status}	: [ ]

	foreach my $file (keys %SCANS_FILES) {
		# checks dim
		
		if ( $SCANS_FILES{$file}{dir_dim} != ($dim_home+3) ) {
		
			push @{ $SCANS_FILES{$file}{errors_list} }, "ERR-DIM";
#			push $SCANS_FILES{$file}{dir_year}{errors_list}, "ERR-DIM";
			$SCANS_FILES{$file}{error_status} = 1;
		}
		# checks dir_year format
		if ( !( $SCANS_FILES{$file}{dir_year} =~ /^[0-9]{4}$/ ) ) {
			push @{ $SCANS_FILES{$file}{errors_list} }, "ERR-YEAR";
			$SCANS_FILES{$file}{error_status} = 1;
		}
	}
}


=begin comment

sub compute_new_filename {
	print "SET NEW FILENAME \n";
	foreach my $file ( sort { $SCANS_FILES{$file_version}{$a} <=> $SCANS_FILES{$file_version}{$b} } (keys %SCANS_FILES) ) {
		print "FILE PAR VERSION : ", $file,"\n";
		my @d = File::Spec->splitdir($SCANS_FILES{$file}{filename_id});
		my @new_filename;
		if ( !( $ICLOUD_FILES{$file}) ){
				$ICLOUD_FILES{$file}++;
				@new_filename = @d;
				splice @new_filename ,$dim_home,1,$ICLOUD_DIR;
		}
		else {
			@new_filename = @d;
			splice @new_filename ,$dim_home,1,$OTHER_DIR;
		} 
		$SCANS_FILES{$file}{new_filename}=join("/",@new_filename);
	}
}

=end comment

=cut

# LATER ADD ERROR
sub pr_sc_in_error {
	print "ERROR STATUS \n";
	foreach my $file (keys %SCANS_FILES) {
		if ( $SCANS_FILES{$file}{error_status} ) {
			print "ERR : ", $SCANS_FILES{$file}{filename_id};
			print join(", ", @{ $SCANS_FILES{$file}{errors_list} }),"\n"; 
		}
		else {
			print "OK : ", $SCANS_FILES{$file}{filename_id},"\n"; 
		} 
	}
}

sub pr_sc_move {
	print "MOVE \n";
	foreach my $file (keys %SCANS_FILES) {
			print $SCANS_FILES{$file}{filename_id},"\t";
			print " | ", $SCANS_FILES{$file}{new_filename},"\n"; 
	}
}
# q:ok
sub remove_in_error  {
	print "REMOVE \n";
	foreach my $file (keys %SCANS_FILES) {
		my $file2remove = $SCANS_FILES{$file}{filename_id};
		if ( $SCANS_FILES{$file}{error_status} ) {
			$nb_scans_in_error++;
			delete $SCANS_FILES{$file};
		}		
	}
}

sub pr_sc_hash {
	print "HASH \n";
	foreach my $file (keys %SCANS_FILES) {
		print $SCANS_FILES{$file}{dir_year},"\t",$SCANS_FILES{$file}{file_version},"\t",$SCANS_FILES{$file}{file_sequence},"\t",$SCANS_FILES{$file}{filename_id},"\n";
	}
}

sub icloud {
	# Sort by :
	#1: dir_year
	#2: dir_event  
	#3: file_sequence
	#4: file_version
	print "ICLOUD \n";
	foreach my $file (sort { $SCANS_FILES{$a}->{dir_year} <=> $SCANS_FILES{$a}->{dir_year} or $SCANS_FILES{$a}->{dir_event} cmp $SCANS_FILES{$b}->{dir_event} or $SCANS_FILES{$a}->{file_sequence} <=> $SCANS_FILES{$b}->{file_sequence} or $SCANS_FILES{$b}->{file_version} <=> $SCANS_FILES{$a}->{file_version}} (keys %SCANS_FILES ) ) {
		my $r_filename = $SCANS_FILES{$file}{file_begin}."_".$SCANS_FILES{$file}{file_sequence}.".".$SCANS_FILES{$file}{file_extension};
		my @d = File::Spec->splitdir($SCANS_FILES{$file}{filename_id});
		my @new_filename;
		if ( $ICLOUD_FILES{$r_filename} ) {
		# already found so move to OTHER_DIR
			$nb_files_v++;
			@new_filename = @d;
			splice @new_filename ,$dim_home,1,$OTHER_DIR;
		}
		else {
		# new so move to ICLOUD_DIR
				$nb_icloud++;
				$ICLOUD_FILES{$r_filename}++;
				@new_filename = splice @d;
				splice @new_filename ,$dim_home,1,$ICLOUD_DIR;
				splice @new_filename ,$dim_home+3,1,$r_filename;
		}
		$SCANS_FILES{$file}{new_filename}=join("/",@new_filename);
		print "NEW : ",$SCANS_FILES{$file}{new_filename},"\n"; 
#		print $SCANS_FILES{$file}{file_version},"\t",$SCANS_FILES{$file}{file_sequence},"\t",$SCANS_FILES{$file}{filename_id},"\n";
#		printf "%-40s %-40s", $SCANS_FILES{$file}{filename},$SCANS_FILES{$file}{new_filename};
#		print "/n";
	}
}



=begin comment

find( 	{ 
'' 				preprocess => sub { return map {  Encode::decode('utf-8-mac', $_)  } @_ }, 
'' 				wanted => \&build_REC_FILE,
'' 			},
'' 			$dir);

# Sort by 

=end comment

=cut

sub copy_files {

	foreach my $file (keys %SCANS_FILES) {
		my($filename, $dirs, $suffix) = fileparse($SCANS_FILES{$file}{new_filename});
			if ( !(-e $dirs) ) {
				mkpath($dirs);
			}				 	    
	    	if ( !(-e $SCANS_FILES{$file}{new_filename}) ) {
	    		if ( copy($SCANS_FILES{$file}{filename_id},$SCANS_FILES{$file}{new_filename}) ) {

	    			print "FILE COPIED: ",$SCANS_FILES{$file}{filename_id},"\n";
					$nb_files_copied++;
					print "Avancement: ",$nb_files_copied," / ",$nb_read,"\n";
	    		}
	    	}
	}
}




### MAIN ###

my %SCANS_FILES;
my %ICLOUD_FILES;

print "START","\n";


if (! (-e $BACKUP_VOLUME) ) {
	my $res = `mkdir $BACKUP_VOLUME`;
	if ( -d $BACKUP_VOLUME ) {
		mount_volume($BACKUP_VOLUME);
	}
	else {
		print "Echec à la création de ",$BACKUP_VOLUME,"\n";	
	}
}	


my $ABS_PICTURES_STEP_2_DIR = File::Spec->catdir( $BACKUP_VOLUME, $REL_PICTURES_STEP_2_DIR );	
my @ABS_PICTURES_STEP_2_DIR = File::Spec->splitdir( $ABS_PICTURES_STEP_2_DIR );

$dim_home = $#ABS_PICTURES_STEP_2_DIR;
print "DIM home : ",$dim_home,"\n";	
	
#	find(\&print_dir, $ABS_PICTURES_STEP_1_DIR );
	
#finddepth( \&check_diapos, $ABS_PICTURES_STEP_2_DIR );
#clean_diapos;
	
find( \&read_diapos, $ABS_PICTURES_STEP_2_DIR );
check_diapos;
#pr_sc_in_error;
remove_in_error;
#pr_sc_hash;
icloud;
copy_files;	
#pr_sc_move;	
	
print "Repository read : ",$ABS_PICTURES_STEP_2_DIR, "\n";
print "Nb read : ",$nb_read,"\n";
print "Nb icloud : ",$nb_icloud,"\n";
print "Nb scans in error : ",$nb_scans_in_error,"\n";
print "Nb v00i : ",$nb_files_v,"\n";