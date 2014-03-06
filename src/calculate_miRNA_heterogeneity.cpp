/*
 * This script is part of the NGS pipeline developed in the Zamore lab and the Weng lab
 * Bo Han (bowhan@me.com)
 */
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <unordered_map>
#include <algorithm>
#include <iomanip>
#include "hairpin.hpp"
using namespace std;
int main (int argc, char** argv)
{
	string usage = R"(
This program calculate the heterogeneity of miRNAs.
It takes two input, first one is the bed file, produced by mapping mature.fa to hairpin.fa to get the coordinates of annoated miRNA on hairpin.
Second input is the bed file produced by mapping your library of interest to hairpin.fa.
<stdout> gives the heterogeneities:
	FivePrimeHeterogeneityOfFivePrimeArm
	ThreePrimeHeterogeneityOfFivePrimArm
	FivePrimeHeterogeneityOfThreePrimeArm
	ThreePrimeHeterogeneityOfThreePrimArm
<stderr> gives the warning messages, including the mismatch of version of hairpin.fa used, et al.

usage:
	program mature2hairpin.bed library2hairpin.bed

contact bowhan@me.com for bugs and questions.
)";
	if (argc != 3) {
		cerr << usage;
		exit (1);
	}
	string line;
	/**! argv[1] is /mature2hairpin.uniq.bed **/

	ifstream in {argv[1]};

	ifstream in2 {argv[2]};

	ofstream out2 {string (argv[2]) + ".relative"};

	unordered_map <string, Hairpin> hairpins;

	while (getline (in, line)) {
		Hairpin hp {line};
		auto found = hairpins.find (hp.getName ());
		if (found == hairpins.end())
			hairpins.insert (make_pair (hp.getName (), hp));
		else {
			found->second.update (hp);
		}
	}
	string::const_iterator iter1, iter2;
	while (getline (in2, line)) {
		iter1 = iter2 = line.cbegin ();
		while (*++iter2!='\t');
		string tempName {iter1, iter2};
		auto found = hairpins.find (tempName);
		if (found != hairpins.end ()) {
			found->second.insert (line);
		}
		else {
			cerr << "Error : hairpin " << tempName << " not found; Most likely you are using outdated version of miRBase to do mapping; could also because it is a miRNA can be assigned to more than one hairpins and you are using unique.bed" << endl;
		}
	}
	for (auto& hp : hairpins) {
		//		hp.second.outputAll (cout);
		hp.second.calculateHeterogeneity ();
		cout << hp.second.getName () << '\t'
				<< std::setprecision(3) << std::fixed
				<< hp.second.getFivePrimeCounter () << '\t'
				<< hp.second.getFivePrimeHeterogeneityOfFivePrimeArm () << '\t'
				<< hp.second.getThreePrimeHeterogeneityOfFivePrimArm () << '\t'
				<< hp.second.getThreePrimeCounter () << '\t'
				<< hp.second.getFivePrimeHeterogeneityOfThreePrimeArm () << '\t'
				<< hp.second.getThreePrimeHeterogeneityOfThreePrimArm () << '\n';
		hp.second.outputAll (out2);
	}
}



