#!/usr/bin/python

#Written by Kiran mathew Koshy.


#Python Script to generate the library.xml file.

import os
import sys
import subprocess 



#Location of kiwix library.
global rootDir

#Library File.
global libFile

#URL Base, will be added to the directory to obtain the download URL.
urlBase="http://download.kiwix.org/zim/"

def usage():
    print "Usage: "
    print "A tool to build library files to Kiwix"
    print "Supports adding diff files"
    print "Usage: create_library.py --dir <library path> --diff <Diff folder> --lib <libfile>"


#Executes a command and returns the output
def runCommand(command):
    p=subprocess.Popen(command,shell=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    op=[]
    for line in p.stdout.readlines():
        op.append(line)
    return op

#Function to return all folders in a folder.
def listDir(dir):
    folders=[]
    for i in os.listdir(dir):
        if(os.path.isdir(os.path.join(dir,i))):
            folders.append(os.path.join(dir,i))
    return folders

#Function to return all files in a folder
def listFiles(dir):
    files=[]
    for i in os.listdir(dir):
        if(os.path.isfile(os.path.join(dir,i))):
            files.append(os.path.join(dir,i))
    return files

#Function to recursively go through each folder in a directory and return the files. 
def listFilesRecursive(dir):
    filelist=[]
    for file in listFiles(dir):
        filelist.append(file)
    for folder in listDir(dir):
        filelist.extend(listFilesRecursive(os.path.join(dir,folder)))
    return filelist


#Function to return only the filename if the entire path of the file is passed:
def filename(file):
    op=""
    for i in range(len(file)-1,-1,-1):
        if(file[i]=='/'):
            return op
        op=file[i]+op
    return op



#Main  function:
if __name__ == "__main__":
    
    global rootDir
    global libFile
    rootList=[]
    if(len(sys.argv)<2):
        print "Not enough arguments"
        usage()
        sys.exit(0)

    
    for word in sys.argv:
        if(word=="-h"):
            usage()
            exit(0)
        if(word=="--help"):
            usage()
            exit(0)
    
    for i in range(0,len(sys.argv)):
        if(sys.argv[i]=="--dir"):
            if(i<(len(sys.argv)-1)):
                rootList.append(sys.argv[i+1])
        if(sys.argv[i]=="--lib"):
            if(i<(len(sys.argv)-1)):
                libFile=sys.argv[i+1]
    #If the rootList variable does not exist:
    if(len(rootList)==0):
        print "Not enough arguments (root directory)"
        usage()
        sys.exit(0)

    #If the libfile variable does not exist:
    if(('libFile' in globals())==False):
        print "Not enough arguments (library File)"
        usage()
        sys.exit(0)
    for directory in rootList: 
        if(os.path.isdir(directory)==False):
            print "[ERROR] Library Folder does not exist: "+directory
            sys.exit(0)
    for i in range(0, len(rootList)):
        rootList[i]=os.path.abspath(rootList[i])
    libFile=os.path.abspath(libFile)
    print "[INFO] Library Folders: "
    for directory in rootList: 
        print directory 
    print "[INFO] Library File: "+ libFile
    print "[INFO] URL Base: "+urlBase
    for directory in rootList:
        #print "Parsing "+directory
        rootDir=directory
        print "[INFO] Parsing library Folder.."
        folders= listDir(rootDir)
        for file in listFilesRecursive(rootDir):
            print file
            if(file[-4:]==".zim"):
                print "Adding file "+file+" to library..."
                localFileName= file[len(rootDir)+1:]
                runCommand('kiwix-manage '+ libFile+' add '+file+' --zimPathToSave="" --url http://download.kiwix.org/zim/'+localFileName+ '.meta4 ')


