# EDGAR Web Crawler
# /\/\/\/\/\/\/\/\/\
# Concept and data structures by Diego Garcia and Øyvind Norli
# Original UNIX implementation appears in Crawling EDGAR [http://dx.doi.org/10.1016/j.srfe.2012.04.001]
# 
# Revised by Justin Shapiro for support in Windows enviornments.
# 
# This implementation of the original Crawling EDGAR concept is more user friendly 
# and allows users with no programatic knowledge to query the SEC.gov server for EDGAR filings
# 
# Facilitates contextual analysis

# import statements
use LWP::UserAgent;
use File::Basename;
use Cwd 'abs_path';
use WWW::Mechanize;

# sub forward declarations
sub LOG;
sub init_logging;
sub init_runfile;
sub master_download;
sub dat_partition;
sub gen_stats;
sub reports_download;
sub find_words;
sub clean_up;
sub save_state;

# create limiting variables
$NUM_FORM_TYPES = 13;
$YEAR_RANGE_LOW = 1996;
$YEAR_RANGE_HIGH = 2016;
$MASTER   = 1;
$DAT_PART = 2;
$STATS    = 3;
$REPORTS  = 4;

# setup logging
init_logging();
open(LOGFILE, ">progress.log"); 
$console_debugging = 1;

# greeting message
system("cls");

print("*************************\n*** EDGAR Web Crawler ***\n*************************\n\n");

# create runtime limiting variables
@rundata = ();
init_runfile();	

# get crawl parameters
@run_vars = get_param();

# set year to fetch data
$crawl_year = $run_vars[0];

# set form-type collection for run
@form_type = @{$run_vars[1]};

# configure wordlist.dat
@wordlist = @{$run_vars[2]};

# sub call routine   # Steps:
master_download();   # 1. download quarterly 'master files'
dat_partition();     # 2. partition 'master files' into individual .dat files per CIK (company)
gen_stats();         # 3. retrieve filing information for each CIK (each .dat file)
reports_download();  # 4. downlad the 'complete submission text files' from SEC.gov for each CIK that matches the selected filing type(s)
find_words();	     # 5. count the number of occurences of a given set of user-defined words by using Perl's 'grep' command to produce a CSV result

LOG("\n\nJOB FINISHED");
close(LOGFILE);

# sub definitions 
sub LOG {
	@param = @_;
	
	print LOGFILE $param[0];
	if ($console_debugging == 1) {
		print($param[0]);
	}
}

sub init_logging {
	$cmd = "cd . > progress.log";
	system($cmd);
}

sub init_runfile {
	$runfile = "runfile.dat";
	
	unless (-f $runfile) {
		system("cd . > " . $runfile);
		open(RUNFILE, ">" , $runfile) or die;
		for ($i = $YEAR_RANGE_LOW; $i <= $YEAR_RANGE_HIGH; $i++) {
			$file_out = "$i" . ",0,0,0,0\n";
			print RUNFILE $file_out;
		}

		close(RUNFILE);
	}
	
	open(RUNFILE, $runfile);
	@runfile_arr = <RUNFILE>;
	close(RUNFILE);
	$runfile_size = @runfile_arr;

	for ($i = 0; $i < $runfile_size; $i++) {
		@arr = split(/,/, $runfile_arr[$i]);
		for ($j = 0; $j < 5; $j++) {
			chomp($arr[$j]);
			push @{$rundata[$i]}, $arr[$j];
		}
	}
}

sub get_param {
	@run_params = [];
	
	print("Set your run parameters:\n\n");
	
	print("Year to Run: ");
	$run_params[0] = <>;
	while ((not ($run_params[0] >= $YEAR_RANGE_LOW)) || $run_params[0] > $YEAR_RANGE_HIGH) {
		print("! \"Year to Run\" must be a year >= " . $YEAR_RANGE_LOW . " and < " . $YEAR_RANGE_HIGH . "!\n\n");
		print("Year to Run: ");
		$run_params[0] = <>;
	}
	chomp($run_params[0]);
	
	$form_list = "(1) 4[/A]\n(2) 6K\n(3) 8K\n(4) 10K\n(5) 10Q\n(6) 13D\n(7) 13F\n(8) 13G\n(9) 424B\n(10) 485[A/B]POS\n(11) N-Q[/A]\n(12) N-CSR[/A]\n(13) N-30D[/A]\n\n";
	print("\nAvailable form types to crawl:\n" . $form_list);
	print("Enter a form type designated by its menu number: ");
	$form_select = <>;
	while ($form_select < 1 || $form_select > $NUM_FORM_TYPES) {
		print("! You must enter any of these: \n " . $form_list . " !\n\n");
		print("Enter a form type designated by its menu number: ");
		$form_select = <>;
    }
   
    @forms = [];
	
	#      Menu Option         Form listed as   -OR-   Form listed as      stats[crawl_year].dat position
	#     -------------      -----------------        ----------------    --------------------------------
	if ($form_select == 1)  { $forms[0] = "4";        $forms[1] = "4\/A";       $forms[2] = 7;  }
	if ($form_select == 2)  { $forms[0] = "6K";       $forms[1] = "6\-K";       $forms[2] = 6;  }
	if ($form_select == 3)  { $forms[0] = "8K";       $forms[1] = "8\-K";       $forms[2] = 5;  }
	if ($form_select == 4)  { $forms[0] = "10K";      $forms[1] = "10\-K";      $forms[2] = 3;  }
	if ($form_select == 5)  { $forms[0] = "10Q";      $forms[1] = "10\-Q";      $forms[2] = 4;  }
	if ($form_select == 6)  { $forms[0] = "13D";      $forms[1] = "";           $forms[2] = 9;  }
	if ($form_select == 7)  { $forms[0] = "13F";      $forms[1] = "";           $forms[2] = 10; }
	if ($form_select == 8)  { $forms[0] = "13G";      $forms[1] = "";           $forms[2] = 8;  }
	if ($form_select == 9)  { $forms[0] = "424B";     $forms[1] = "";           $forms[2] = 11; }
	if ($form_select == 10) { $forms[0] = "485APOS";  $forms[1] = "485BPOS";    $forms[2] = 12; }
	if ($form_select == 11) { $forms[0] = "N\-Q";     $forms[1] = "N\-Q\/A";    $forms[2] = 13; }
	if ($form_select == 12) { $forms[0] = "N\-CSR";   $forms[1] = "N\-CSR\/A";  $forms[2] = 14; }
	if ($form_select == 13) { $forms[0] = "N\-30D";   $forms[1] = "N\-30D\/A";  $forms[2] = 15; }
	
	$run_params[1] = \@forms;
	
	print("\nThis program will count the occurrences of the following words:\n");
	print("[Instructions: Type one word or phrase per line. When finished, enter \"done\" (without quotes)]\n\n");
	
	@words = [];
	my $word_loop = "";
	my $count = 0;
	while ($word_loop ne "done") {
		print("     wordlist.dat[" . $count . "]: ");
		$words[$count] = <>;
		chomp($words[$count]);
		while (not $words[$count]) {
			print("     ! Cannot be empty. If finished, enter \"done\" (without quotes) !\n\n");
			print("     Enter wordlist.dat[" . $count . "]: ");
			$words[$count] = <>;
			chomp($words[$count]);
		}
		
		$word_loop = $words[$count];
		$count = $count + 1;
	}
	
	pop @words;
	
	$run_params[2] = \@words;
	
	
	print("\nEverything looks good. Press ENTER to start the run...");
	<>;
	
	system("cls");
	
	return @run_params;
}

sub master_download {
	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	$ua->env_proxy;

	if ($rundata[$crawl_year - $YEAR_RANGE_LOW][$MASTER] != 1) {
		$pathname = $crawl_year . "MASTER";
		$dircmd = "mkdir " . $pathname;
		system($dircmd);
		
		for($i = 1; $i < 5; $i = $i + 1) {
			$quarter = "QTR" . $i;
			$filegrab = "ftp://ftp.sec.gov/edgar/full-index/" . $crawl_year . "/" . $quarter . "/master.gz";

			LOG("Downloading master files from EDGAR: " . $crawl_year . $quarter . "master\n");
			
			my $response = $ua->get($filegrab);

			$filename = $pathname . "\\" . $crawl_year . $quarter . "master";
			open(DOWNLOADFILE, ">" . $filename);
			
			if ($response->is_success) {
				print DOWNLOADFILE $response->decoded_content; 
			} else {
				$i = $i - 1;
				print("Waiting on server...\n");
			}
			
			close(DOWNLOADFILE);
		}
		
		$rundata[$crawl_year - $YEAR_RANGE_LOW][$MASTER] = 1;
		save_state();
	}
}

sub dat_partition {		
	if ($rundata[$crawl_year - $YEAR_RANGE_LOW][$DAT_PART] != 1) {
		$dat_locations = "dat_locations_$crawl_year.dat";
		system("cd . > $dat_locations");
		
		$pathname = $crawl_year . "CIKs";
		$dircmd = "mkdir " . $pathname;
		system($dircmd);
		
		for($i = 1; $ i< 5; $i = $i + 1) {
			$filea = $crawl_year . "MASTER" . "\\" . $crawl_year . "QTR" . $i . "master";
			open(MASTERFILE, $filea); 
			
			@linesgn = <MASTERFILE>;
			close(MASTERFILE);
			$sizegn = @linesgn;

			$numerox = sprintf("%03d", $numeroj); 
			$dircmd = "mkdir " . $pathname . "\\" . $numerox . ">nul 2>&1";
			system($dircmd); 
			
			LOG("Creating directory " . $crawl_year . "CIKs\\" . $numerox . "\n");

			$last_dir = "";
			for($j = 0; $j < $sizegn; $j++) {
				if($linesgn[$j] =~ m/txt/) {
					@arraydata = split(/\|/, $linesgn[$j]); 
					$numero = sprintf("%07d", $arraydata[0]);
					$fileb = $pathname . "\\" . $numerox . "\\" . $numero . ".dat"; 
					$filec = ">>" . $fileb;

					open(DATFILE, $filec); 
					
					$datagn = $linesgn[$j];
					$datagn =~ s/,/;/g;
					$datagn =~ s/\|/,/g;
					
					print DATFILE $datagn;
					
					$this_dir = dirname(abs_path($0)) . "\\" . $fileb . "\n";
					if ($last_dir ne $this_dir) {
						open(DATLOCATIONS, ">>", $dat_locations);
						print DATLOCATIONS $this_dir;
						$last_dir = $this_dir;
						close(DATLOCATIONS);
					}
					
					close(DATFILE);
				}
				
				if($j > 500 * ($numeroj + 1)) { 
					$numeroj = $numeroj + 1;
					$numerox = sprintf("%03d", $numeroj);
					$dircmd = "mkdir " . $pathname . "\\" . $numerox . ">nul 2>&1";
					system($dircmd); 
					
					LOG("Creating directory " . $crawl_year . "CIKs\\" . $numerox . "\n");
				}
			}
		}
		
		$rundata[$crawl_year - $YEAR_RANGE_LOW][$DAT_PART] = 1;
		save_state();
	}
}

sub gen_stats {
	if ($rundata[$crawl_year -$YEAR_RANGE_LOW][$STATS] != 1) {
		open(DATFILE, "dat_locations_$crawl_year.dat"); 
		@linesgn = <DATFILE>;
		close(DATFILE);
		
		$sizegn = @linesgn;
		
		$stats_file = "stats" . $crawl_year . ".dat";
			
		open(STATFILE, ">", $stats_file);

		for($i = 0; $i < $sizegn; $i = $i + 1) {
			if($linesgn[$i] =~ m/dat/) {
				$filename = $linesgn[$i];
				chomp($filename);
				
				LOG("Retrieving filing information for " . $filename . "\n");

				$fourk = $sixk = $eightk = $tenk = $tenq = $code424b = 0;
				$thirteenf = $thirteeng = $thirteend = 0;
				$abpos = $nq = $ncsr = $n30d = 0;
				
				open(DATAFILE, $filename);
				@datafile = <DATAFILE>;
				close(DATAFILE);

				$cikcode = basename($filename);
				$cikcode =~ s/.dat//g;

				$countlines = @datafile;
				for($j = 0; $j < $countlines; $j = $j + 1) {
					@arraydata = split(/,/, $datafile[$j]);
					if($arraydata[2] == "4"       || $arraydata[2] == "4\/A")      { $fourk  = $fourk  + 1; }
					if($arraydata[2] =~ /10K/     || $arraydata[2] =~ /10\-K/)     { $tenk   = $tenk   + 1; }
					if($arraydata[2] =~ /10Q/     || $arraydata[2] =~ /10\-Q/)     { $tenq   = $tenq   + 1; }
					if($arraydata[2] =~ /8K/      || $arraydata[2] =~ /8\-K/)      { $eightk = $eightk + 1; }
					if($arraydata[2] =~ /6K/      || $arraydata[2] =~ /6\-K/)      { $sixk   = $sixk   + 1; }
					if($arraydata[2] =~ /485APOS/ || $arraydata[2] =~ /485BPOS/)   { $abpos  = $abpos  + 1; }
					if($arraydata[2] =~ /N\-Q/    || $arraydata[2] =~ /N\-Q\/A/)   { $nq     = $nq     + 1; }
					if($arraydata[2] =~ /N\-CSR/  || $arraydata[2] =~ /N\-CSR\/A/) { $ncsr   = $ncsr   + 1; }
					if($arraydata[2] =~ /N\-30D/  || $arraydata[2] =~ /N\-30D\/A/) { $n30d   = $n30d   + 1; }
					if($arraydata[2] =~ /13F/)  { $thirteenf = $thirteenf + 1; }
					if($arraydata[2] =~ /13G/)  { $thirteeng = $thirteeng + 1; }
					if($arraydata[2] =~ /13D/)  { $thirteend = $thirteend + 1; }
					if($arraydata[2] =~ /424B/) { $code424b = $code424b + 1; }
				}

				print STATFILE "$filename,$countlines,$cikcode,$tenk,$tenq,$eightk,$sixk,$fourk,";
				print STATFILE "$thirteeng,$thirteend,$thirteenf,$code424b,$abpos,$nq,$ncsr,$n30d\n";
			}
		}

		close(STATFILE);
		$rundata[$crawl_year -$YEAR_RANGE_LOW][$STATS] = 1;
		save_state();
	}
}

sub reports_download {
	$reports_file = "report_locations_" . $crawl_year . "_" . $form_type[0] . ".dat";
	$reports_file_exists = 1;
	
	unless (-f $reports_file) {
		$reports_file_exists = 0;
	}
	
	if (($rundata[$crawl_year - $YEAR_RANGE_LOW][$REPORTS] != 1) || ($reports_file_exists == 0)) {
		
		system("cd . > $reports_file");
		
		open(STATSFILE, "stats". $crawl_year . ".dat");
		@linesgn = <STATSFILE>;
		close(STATSFILE);
		
		$sizegn = @linesgn;

		for($i = 0; $i < $sizegn; $i = $i + 1) {
			@arraydata = split(/,/, $linesgn[$i]);

			if($arraydata[$form_type[2]] > 0) {
				@arraydatab = split(/,/, $linesgn[$i]);

				$filepath = $arraydatab[0];
				$filename = basename($filepath);
				$filepath =~ s/$filename//g; 
				$cik = $arraydatab[2];
				
				$makemed = "mkdir " . $filepath . $cik . ">nul 2>&1";
				system($makemed);
						
				open(DATALEN, $arraydatab[0]);
				@datagn = <DATALEN>;
				close(DATALEN);
				
				$lenx = @datagn;

				for($j = 0; $j < $lenx; $j = $j + 1) {
					@arraydata = split(/\,/, $datagn[$j]);
					
					if($arraydata[2] =~ m/$form_type[0]/ || $arraydata[2] =~ /$form_type[1]/) {
						my $mech = WWW::Mechanize->new( autocheck => 0 );
						
						@arraydatad = split(/\//, $arraydata[4]);
						
						$filenamea = $filepath . $cik . "\\" . $arraydatad[3];
						chomp($filenamea);
						
						$filecrawl = "https://www.sec.gov/Archives/" . $arraydata[4];
						
						LOG("Downloading: " . $filecrawl);
									
						open(REPORTINFILE, '>', $filenamea);
						$mech->get($filecrawl);
						print REPORTINFILE $mech->response->decoded_content;
						close REPORTINFILE;
						
						LOG("Writing:     " . $filenamea . "\n\n");
						
						open(REPORTOUTFILE, ">>", "$reports_file");
						print REPORTOUTFILE $filenamea . "\n";
						close REPORTOUTFILE;
					}
				}
			}
		}
		$rundata[$crawl_year -$YEAR_RANGE_LOW][$REPORTS] = 1;
		save_state();
	}
}

sub find_words {
	get_wordlist();
		
	open(REPORTFILE, "report_locations_" . $crawl_year . "_" . $form_type[0] . ".dat");
	@linesgn = <REPORTFILE>;
	close(REPORTFILE);
	
	$sizegn = @linesgn;

	open(WORDFILE, "wordlist.dat");
	@wordlisting = <WORDFILE>;
	close(WORDFILE);
	
	$lengthfile = @wordlisting;
	
	$result_filename = "result" . "-" . $crawl_year . " (" . $form_type[0] . ").csv";
	
	$num_runs = 0;
	while (-f $result_filename) {
		$num_runs++;
		$result_filename = "result" . "-" . $crawl_year . " (" . $form_type[0] . ") [$num_runs].csv";
	}
	
	open(RESULTFILE, ">" . $result_filename);
	print RESULTFILE "URL,", "CIK";
	
	for ($i = 0; $i < $lengthfile; $i = $i + 1) {
		chomp($wordlisting[$i]);
		print RESULTFILE ",$wordlisting[$i]";
	}

	print RESULTFILE "\n";

	for($i = 0; $i < $lengthfile; $i = $i + 1) {
		$litiword[$i] = $wordlisting[$i];
		chomp($litiword[$i]);
	}

	for($i = 0; $i < $sizegn; $i = $i + 1) {
		chomp($linesgn[$i]);
		$dirname = $linesgn[$i];
		$filename = basename($dirname);
		$dirname =~ s/$filename//g;
		@filepath = split(/\\/, $dirname);
		$cik = $filepath[4];
		
		open(DATAFILING, $linesgn[$i]);
		@datafiling = <DATAFILING>;
		close(DATAFILING);
		
		$URL = "https://www.sec.gov/Archives/edgar/data/" . $cik . "/" . $filename;

		LOG("Crawling " . $URL . "\n");
		
		print RESULTFILE $URL, "," . $cik;

		for($j = 0; $j < $lengthfile; $j = $j + 1) {
			$countwords[$j] = 0;
			my $count = grep(/\b$litiword[$j]\b/ig, @datafiling);
			$countwords[$j] = $count;
			print RESULTFILE ",$countwords[$j]";
		}
		print RESULTFILE "\n";
	}
	
	close(RESULTFILE);
}

sub get_wordlist() {
	LOG("Generating wordlist.dat\n");
	
	system("del wordlist.dat /F /Q");
	system("cd. > wordlist.dat");
	$listsize = @wordlist;

	open(WORDLIST, ">>", "wordlist.dat");

	for ($i = 0; $i < $listsize; $i = $i + 1) {
		print WORDLIST $wordlist[$i] . "\n";
	}

	close(WORDLIST);
}

sub save_state {
	system("del runfile.dat /F /Q");
	system("cd . > runfile.dat");
	
	open(RUNFILE, ">", "runfile.dat");
	@runfile_arr = <RUNFILE>;
	$runfile_size = @runfile_arr;
	
	for ($i = 0; $i < $YEAR_RANGE_HIGH - $YEAR_RANGE_LOW; $i++) {
		for ($j = 0; $j < 5; $j++) {
			if ($j != 4) {
				print RUNFILE $rundata[$i][$j] . ",";
			} else {
				print RUNFILE $rundata[$i][$j];
			}
		}
		print RUNFILE "\n";
	}
	
	close(RUNFILE);
}