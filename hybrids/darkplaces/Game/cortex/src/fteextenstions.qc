// fteextensions.qc - Definitions for FTEQW advanced features
#pragma target fte

// TCP Socket Builtins (FTEQW extensions)
float(string addr) TCP_Connect = #360;
void(float sock) TCP_Close = #361;
void(float sock, string data) TCP_Send = #362;

// String manipulation (FTEQW extensions)
// Note: ftos and bprint are already in defs.qc
// strcat is FTE-specific
string(string s1, optional string s2, optional string s3, optional string s4, optional string s5, optional string s6, optional string s7, optional string s8) strcat = #115;