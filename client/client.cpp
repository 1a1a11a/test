#include <iostream>
#include <fstream>
#include <stdio.h>
#include <queue>
#include <unordered_map>
#include <vector>
#include <utility>
#include <curl/curl.h>
#include <thread>
#include <mutex>
#include <sstream>
#include <stdexcept>
#include <chrono>
#include <atomic>
#include <string>
#include <stdlib.h>
#include <math.h>
#include <random>
using namespace std;
volatile bool queueFull;
volatile bool running;
mutex urlMutex;
mutex histMutex;
//key, length TODO: length calculation is broken
queue<pair<string, uint64_t>> urlQueue;
char* path;
string cacheip;
ofstream outTp;
uint64_t mean;
default_random_engine generator;
poisson_distribution<int> distribution;

std::atomic<long> bytes;
std::atomic<long> reqs;

unordered_map<double,long> histData;

static size_t throw_away(void *ptr, size_t size, size_t nmemb, void *data)
{
  (void)ptr;
  (void)data;
  return (size_t)(size * nmemb);
}


void histogram(double val){
  histMutex.lock();
  histData[round(val*10)/10.0]++;
  histMutex.unlock();
}
  
int measureThread() {
  string currentID;
  uint64_t current_len;

    CURL *curl_handle;
    /* init the curl session */ 
    curl_handle = curl_easy_init();
    /*include header pragmas*/
    struct curl_slist *headers=NULL; // init to NULL is important 
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    /* no progress meter please */ 
    curl_easy_setopt(curl_handle, CURLOPT_NOPROGRESS, 1L);
    /* send all data to this function  */
    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, throw_away);
    //    curl_easy_setopt(curl_handle, CURLOPT_HEADERFUNCTION, write_string);
    //    curl_easy_setopt(curl_handle, CURLOPT_WRITEHEADER, &currentHeader);
    /* set buffer for content */
    //    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, &currentBody);

    while (!queueFull || !::urlQueue.empty() ) {

      urlMutex.lock();
      if (!::urlQueue.empty()){
	currentID = ::urlQueue.front().first;
	current_len = ::urlQueue.front().second;

	urlQueue.pop();
	urlMutex.unlock();
      }
      else {
	urlMutex.unlock();
	//      cerr << "sleep for " << 10 << endl;
	this_thread::sleep_for (chrono::milliseconds(10));//wait a little bit
	continue;
      }
      //zhenyu: sleep 10 milliseconds
      auto t_sleep = distribution(generator);
      this_thread::sleep_for (chrono::microseconds(t_sleep));//wait a little bit
      //cerr << "get " << cacheip + currentID << "\n";
      /* set URL to get */ 
      curl_easy_setopt(curl_handle, CURLOPT_URL, (cacheip + currentID).c_str());
      //fetch URL
      CURLcode res;
      chrono::high_resolution_clock::time_point start;
      chrono::high_resolution_clock::time_point end;
      // if couldn't connect, try again
      for(int failc=0; failc<10; failc++) {
	//profile latency and perform
	start = chrono::high_resolution_clock::now();
	res = curl_easy_perform(curl_handle);
	end = chrono::high_resolution_clock::now();	
	if(res == CURLE_OK)
	  break;
	else if(res == CURLE_COULDNT_CONNECT)
	  this_thread::sleep_for (chrono::milliseconds(1));//wait a little bit
	else
	  continue; //fail and don't try again
      }

      //get elapsed time
      const long timeElapsed_ns = chrono::duration_cast<chrono::nanoseconds>(end - start).count();
      histogram(log10(double(timeElapsed_ns)));
      
//      double content_length = 0.0;
//      res = curl_easy_getinfo(curl_handle, CURLINFO_CONTENT_LENGTH_DOWNLOAD,
//			      &content_length);
      if((CURLE_OK == res)) {
	bytes += (long)current_len;
	reqs++;
      }

      currentID.clear();
    }

    /* cleanup curl stuff */
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl_handle);
    
  return 0;
}

int requestCreate(){
  ifstream infile;
  infile.open(path);
  unordered_map<long, long> osizes;
  long time, id;
  uint64_t length;
  while (infile >> time >> id >> length) {
    if(urlQueue.size()>1000) {
      this_thread::sleep_for (chrono::milliseconds(10));
    }
    urlMutex.lock();
    urlQueue.push({to_string(id), length});
    urlMutex.unlock();
  }

  return 0;
}

void output() {
  while (running) {
    chrono::high_resolution_clock::time_point start = chrono::high_resolution_clock::now();
    reqs.store(0);
    bytes.store(0);
    this_thread::sleep_for (chrono::milliseconds(1000));
    const long tmpr = reqs.load();
    const long tmpb = bytes.load();
    chrono::high_resolution_clock::time_point end = chrono::high_resolution_clock::now();
    const long timeElapsed = chrono::duration_cast<chrono::milliseconds>(end - start).count();
    outTp << tmpr << " " << tmpb << " " << timeElapsed << endl;
  }
}

int main (int argc, char* argv[]) {

  // parameters
  if(argc != 7) {
    cerr << "three params: path noThreads cacheIP outTp outHist mean(us)" << endl;
    return 1;
  }
  path = argv[1];
  const int numberOfThreads = atoi(argv[2]);
  cacheip = argv[3];

  bytes.store(0);
  reqs.store(0);

  outTp.open(argv[4]);
  mean = stoull(argv[6]);
  distribution = poisson_distribution<int>(mean);

  // init curl
  curl_global_init(CURL_GLOBAL_ALL);

  //perform measurements in different threads, save time stamps (global - rough, local - exact)
  cerr << "Starting threads" << endl;
  queueFull = false;
  ::running = true;
  thread threads[numberOfThreads];
  thread outputth = thread (output);
  //starting threads
  for (int i=0; i < numberOfThreads; i++){
    threads[i] = thread (measureThread);
  }
  // start creating queue
  chrono::high_resolution_clock::time_point ostart = chrono::high_resolution_clock::now();
  requestCreate();
  queueFull = true;
  cerr << "Finished queue\n";
  for (int i=0; i < numberOfThreads; i++){
    threads[i].join();
  }
  chrono::high_resolution_clock::time_point oend = chrono::high_resolution_clock::now();
  long otimeElapsed = chrono::duration_cast<chrono::milliseconds>(oend - ostart).count();
  ::running = false;
  cerr << "Duration: " << otimeElapsed << endl;
  outputth.join();
  cerr << "Finished threads\n";
  curl_global_cleanup();

  ofstream outHist;
  outHist.open(argv[5]);
  for(auto it: histData)
    outHist << it.first << " " << it.second << endl;

  return 0;
}
