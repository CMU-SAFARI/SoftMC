#include <stdio.h>
#include <riffa.h>
#include <cassert>
#include <string.h>
#include <iostream>
#include <cmath>
#include "softmc.h"

using namespace std;


void printHelp(char* argv[]){
	cout << "A sample application that tests retention time of DRAM cells using SoftMC" << endl;
	cout << "Usage:" << argv[0] << " [REFRESH INTERVAL]" << endl; 
	cout << "The Refresh Interval should be a positive integer, indicating the target retention time in milliseconds." << endl;
}

int main(int argc, char* argv[]){

    SoftMCPlatform platform;
    int err;

    if((err = platform.init()) != SOFTMC_SUCCESS){
        cerr << "Could not initialize SoftMC Platform: " << err << endl;
    }

    cout << "Successfully opened " << platform.open_fpgas.size() <<
        " SoftMC FPGAs." << endl;

    platform.reset(); // resets current FPGA. Keep this, recovers the FPGA
                      // from previous likely unwanted state
    

	//if(argc != 2 || strcmp(argv[1], "--help") == 0){
	//	printHelp(argv);
	//	return -2;
	//}

    //string s_ref(argv[1]);
    //int refresh_interval = 0;

    //try{
    //    refresh_interval = stoi(s_ref);    
    //}catch(...){
    //    printHelp(argv);
    //    return -3;
    //}

    //if(refresh_interval <= 0){
    //    printHelp(argv);
    //    return -4;
    //}


  	//printf("Starting Retention Time Test @ %d ms! \n", refresh_interval);

	//testRetention(fpga, refresh_interval);

	//printf("The test has been completed! \n");
    
    cout << "The program has finished." << endl;

	return 0;
}
