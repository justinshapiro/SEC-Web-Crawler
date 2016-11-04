## Crawling SEC's EDGAR database with Perl ##

This application was developed by Justin Shapiro for Finance faculty at CU Denver. The purpose of the tool is to retrieve company filings (8-K, 10-K, etc) from SEC's [EDGAR database](https://www.sec.gov/edgar/searchedgar/webusers.htm) and count the occurrences of a user-determined list of words. For each company filing (represented by a CIK), the number of occurrences of each words are output to a CSV file.

This code is inspired by a publication by Diego Garcia and Øyvind Norli in [Crawling EDGAR](http://dx.doi.org/10.1016/j.srfe.2012.04.001). Garcia and Norli's conceptualization of an EDGAR web crawler and analyzer of company filings is implemented for UNIX systems in Perl. Although Perl is a common language used in such a discipline, its main advantage in this case is its built-in `grep` command. Since Perl programs can be run on UNIX and Windows platforms, it provides Windows application developers the ability to take advantage of `grep`-like characteristics that would otherwise be unavailable on the platform.

This implementation of the EDGAR web crawler improves, yet is distinct from, Garcia and Norli's implementation in the following ways:

 1. Ported to work with Windows shell and directory structures
 2. Gives the user the ability to resume a previously interrupted run by replacing the the `ls -la` Windows analog of `dir /s /b` with a manual population facility using a for-loop and keeping count of which segments of code have already been run. This also prevents duplicate files being downloaded, making the program more efficient and time-saving
 3. Lets the user input only one year to retrieve filings for, the type of filings to retrieve for that year, and a `wordlist.dat` right at the command line. Error handling is implemented here in order to obtain the correct range of results from the user
 4. N-Q, N-CSR, and N-30 filings were added to the list of filing statements that are available to be retrieved
 5. The original 5-file implementation was partitioned into subprograms and placed all in one file for easy subprogram referencing
 6. Output is formatted into a CSV containing the URL of the filing, corresponding CIK that submitted the filing, and the count of each word from the program-generated `wordlist.dat`
 7. Syntax was updated to support lexical scoping and to reflect the current state of EDGAR's directory structure
 8. Status updates are printed to the terminal and recorded in a file so that the user can see how far along the program is and if there are any errors

Overall, this implementation of the EDGAR web crawler is much more user-friendly and is the potential first step to developing an application that performs financial contextual analysis through web crawling. Here, the user simply enters the requested information and then leaves the program unattended. This is a very convenient improvement, since some runs can take up to a day to complete. 

Users who run this program for years 1996 - current with, at most, an 8-K filling retrieval should expect 4-5 TB of information to be downloaded and stored on the disk.

 