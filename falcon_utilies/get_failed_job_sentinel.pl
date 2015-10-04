#!/usr/bin/env perl
#find all sh files in falcon directories

use strict;
use warnings;
use File::Spec;
use Getopt::Std;
use Data::Dumper;

my $usage = "Usage: $0 <ID list of failed ct/m jobs> [current wd (by default) or falcon root dir containing 0-rawreads,1-preads_ovl,2-asm-falcon]\n".
" -n	dry run\n";
my %options;
my $step = "
0. record all Done, mLog, dSh files    
1. remove c_ID_done
2. remove m_ID_done
3. combine all rp_ID.log (m jobs)
4. get all missing las files by looking at lines containing 'Segmentation fault', the las files are named as 'raw_reads.749.raw_reads.234.N0','raw_reads.749.raw_reads.234.C1', ...
5. combine all rj_*.sh files XXDISCARDEDXX
6. identify rj_*.sh files that contain missing las files
7. remove corresponding job_*_done files

every time _done files are removed, report number of removals
";
getopts("n",\%options);
die $usage unless @ARGV == 1 or @ARGV == 2;
my $dir;
if(@ARGV == 1) {
    $dir = $ENV{PWD};
} else {
    $dir = $ARGV[1];
}
my @subdir = qw/0-rawreads 1-preads_ovl 2-asm-falcon/;
@subdir = map {File::Spec->catfile($dir,$_)} @subdir;
my $output;
my $reg = "\\.sh\$";
my %id = &getIDs($ARGV[0]);
#c for ct jobs, m for m jobs, d for daligner jobs
my (@rerunC,@rerunM,%missingLas,@rerunD,@rerunDone);
my (@cDone, @mLog, @mDone, @dDone, @Dsh);
my (%c,%m,%d);
my $struct = "
c = {done=>
     sh=>
     log=>
     }
IDs will be used as keys
";

#check dir
for my $i($dir,@subdir) {
    die "$i not found\n" unless -d $i;
}

#0. record all Done, mLog, dSh files    
for my $i(@subdir) {
#count total jobs
    warn "Processing $i\n";
    opendir (DIR, $i) or die "Error: cannot read from dir $i\n";
    my @alldir = readdir(DIR);
    my @founddir = grep { m/^m_/ || m/^job_/ } @alldir;
    closedir (DIR);

    if($i =~ /0-rawreads/) {
	#count preads c_xxxx.sh jobs
	push @founddir, 'preads';
    }
    #look into each of the folder
    for my $j (0 .. @founddir-1) {
	my $dir = File::Spec->catdir($i,$founddir[$j]);
	if($dir =~ /job_(\w+)/) {
	    #for d jobs
	    $d{$1} = {
		done=>File::Spec->catfile($dir,"job_$1_done"),
		log=>File::Spec->catfile($dir,"rj_$1.log"),
		sh=>File::Spec->catfile($dir,"rj_$1.sh"),
	    };
	} elsif ($dir =~ /m_(\d+)/) {
	    #m jobs
	    $m{$1} = {
		done=>File::Spec->catfile($dir,"m_$1_done"),
		log=>File::Spec->catfile($dir,"rp_$1.log"),
		sh=>File::Spec->catfile($dir,"m_$1.sh"),
	    };
	} elsif ($dir =~ /preads/) {
	    opendir (DIR, $dir) or die "Error: cannot read from directory $dir\n";
	    for my $k(readdir DIR) {
		#ct jobs
		if($k =~ /cp_(\d+).sh/) {
		    $c{$1} = {
			done=>File::Spec->catfile($dir,"c_$1_done"),
			log=>File::Spec->catfile($dir,"c_$1.log"),
			sh=>File::Spec->catfile($dir,"cp_$1.sh"),
		    };
		}
	    }
	    closedir(DIR);
	} else {
	    die "$dir unknown type dir\n";
	}
	print STDERR "Scanning subfolders: ",sprintf("%.2f", ($j+1)/@founddir*100), "% completed\r";
    }
}
#1. remove c_ID_done
#2. remove m_ID_done
@rerunDone = map {$c{$_}->{'done'}} (grep {$id{$_}} keys %c);
push @rerunDone,map {$m{$_}->{'done'}} (grep {$id{$_}} keys %m);
#3. combine all rp_ID.log (m jobs)
#4. get all missing las files by looking at lines containing 'Segmentation fault', the las files are named as 'raw_reads.749.raw_reads.234.N0','raw_reads.749.raw_reads.234.C1', ...
%missingLas = &getMissingLas(map {$m{$_}->{'log'}} (grep {$id{$_}} keys %m));
#6. identify rj_*.sh files that contain missing las files
#7. remove corresponding job_*_done files
my %dJobId = &getFailedDJobId(\%d,\%missingLas);
push @rerunDone,map {$d{$_}->{'done'}} (grep {$dJobId{$_}} keys %d);
warn "The following files should be removed\n";
print "$_\n" for @rerunDone;
    warn "Still Missing some .las: $_\n" for grep {$missingLas{$_}} keys %missingLas;
######################################
sub getMissingLas {
    #take list of logs
    #look for missing las files caused by Segmentation fault
    warn "Looking for missing .las files\n";
    my @return;
    my $example = "
    /home/yunfeiguo/projects/PacBio_reference_genome/falcon_aln/hx1_20150716/0-rawreads/m_00749/m_00749.sh: line 237:  5492 Segmentation fault      (core dumped) LAsort -v raw_reads.749.raw_reads.234.C0 raw_reads.749.raw_reads.234.N0 raw_reads.749.raw_reads.234.C1 raw_reads.749.raw_reads.234.N1 raw_reads.749.raw_reads.234.C2 raw_reads.749.raw_reads.234.N2 raw_reads.749.raw_reads.234.C3 raw_reads.749.raw_reads.234.N3
";
    for my $i(@_) {
	open IN,'<',$i or die "open($i): $!\n";
	while(<IN>) {
	    if(/Segmentation fault/) {
		my @las = /(raw_reads\.\d+\.raw_reads\.\d+\.\w+)/g;
		push @return,@las;
	    }
	}
	close IN;
    }
    my %return;
    for my $i(@return) {
	my $prefix=$i;
	$prefix=~s/(.*)\.[CN]\d/$1/;
	$return{$prefix} = 1;
    }
    warn "Missing .las: $_\n" for keys %return;
    return(%return);
}
sub getFailedDJobId {
    #take all d jobs and missing LAS files
    #return a hash with failed job IDs as keys
    warn "Looking for failed d jobs\n";
    my %return;
    my $d = shift;
    my $las = shift;
    my $example = '/usr/bin/time daligner -v -t16 -H6000 -e0.7 -s1000 raw_reads.802 raw_reads.230 raw_reads.231 ...';
    my $count = 0;
    for my $i(keys %$d) {
	my ($N,$pairStart,$pairEnd);
	open IN,"<",$d->{$i}->{'sh'} or die $d->{$i}->{'sh'},"open: $!\n";
	while(<IN>) {
	    if(/daligner.*?raw_reads\.(\d+) raw_reads\.(\d+).*?raw_reads\.(\d+) >>/) {
		#figure out N from the following command
		#every las file name contains an N and another number P
		# pairStart <= P <= pairEnd
		($N,$pairStart,$pairEnd) = ($1,$2,$3);
		#warn "$i for 607($1,$2,$3): $_\n" if $N == 607;
		last;
	    } elsif (/daligner.*?raw_reads\.(\d+) raw_reads\.(\d+).*? >>/) {
		#sometimes, only two input files
		($N,$pairStart) = ($1,$2,$3);
		$pairEnd = $pairStart;
		#warn "$i for 607($1,$2,$3): $_\n" if $N == 607;
		last;
	    }
	}
	close IN;
	die "$i: unknown N\n" unless defined $N && defined $pairStart && defined $pairEnd;
	for my $j(keys %$las) {
	    #warn "$j: $N,$pairStart,$pairEnd\n" if $N == 607 and $pairStart == 1;
	    if($las->{$j} && &isParent($j,$N,$pairStart,$pairEnd)) {
		#if the missing las file contains N,
		#and P is within the expected range
		#then we should rerun this d job
		$return{$i} = 1;
		$las->{$j} = 0;
		warn "job $i is parent of $j\n";
	    }
	}
	#print STDERR sprintf("%.2f", ($count+1)/(keys %$d)*100), "% completed\r";
	$count++;
    }
    return(%return);
}
sub isParent {
    #take las file name
    #N, p range for a d job
    #determine if the d job is parent of the las file

    #only two possible scenarios, 1st number in las name is N
    #2nd number in las name is N
    my $f = shift;
    my ($N,$p1,$p2) = @_;
    my ($first,$second) = $f=~/.*?\.(\d+)\..*?\.(\d+)$/ or die "unknown las file name: $f\n";
    #use || instead of 'or'!!!!!pay attention to precedence
    my $result = ($first == $N && $second >= $p1 && $second <= $p2) || ($second == $N && $first >= $p1 && $first <= $p2);
    #if($f eq 'raw_reads.21.raw_reads.607' and ($N == 21 or $N == 607)) {
    #    warn "first,second in <<$f>>\n";
    #    warn "$first,$second\n";
    #    warn "$N,$p1,$p2\n";
    #    warn "result: $result\n";
    #    print "boolean\n";
    #print $first == $N,"\n";
    #print $second >= $p1 && $second <= $p2,"\n";
    #print ($first == $N && $second >= $p1 && $second <= $p2),"\n";
    #print $second == $N,"\n";
    #print $first >= $p1 && $first <= $p2,"\n";
    #print $second == $N && $first >= $p1 && $first <= $p2,"\n";
    #}
    return ($result);
}
sub getIDs {
    my $file = shift;
    die "$file is not file\n" unless -f $file or -l $file;
    my @id = `cat $file`;
    chomp @id;
    my %id = map { ($_=>1) } @id;
    return(%id);
}
