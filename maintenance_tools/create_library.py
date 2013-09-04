#Written by Kiran mathew Koshy.


#Python Script to generate the library.xml file.

import os
import sys
import subprocess 


#Name of the folder in which the diff files will be kept.
#The diff Folder should be inside the library.
diffFolderName="diff"

rootDir="/var/www/download.kiwix.org/zim/"
libFile="/var/www/download.kiwix.org/zim/library.xml"
diffFolder=rootDir+'/'+diffFolderName

#URL Base, will be added to the directory to obtain the download URL.
urlBase="http://download.kiwix.org/zim"
if(urlBase[len(urlBase)-1]!='/'):
    urlBase=urlBase+"/"



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
def usage():
    print "Usage: "
    print "A tool to build library files to Kiwix"
    print "Supports adding diff files"
    print "Usage: create_library.py <library path> "



#Main  function:
if __name__ == "__main__":
    if(len(sys.argv)>=2):
    	if(sys.argv[1]=="--help"):
       	    usage()
            sys.exit(0)
    if(os.path.isdir(rootDir)==False):
        print "[ERROR] Library Folder does not exist."
        sys.exit(0)
    if(os.path.isdir(diffFolder)==False):
        print "[ERROR] Diff Folder does not exist."
        sys.exit(0)    
    print "[INFO] Library Folder: "+rootDir
    print "[INFO] Library File: "+ libFile
    print "[INFO] URL Base: "+urlBase
    print "[INFO] Diff Folder: "+diffFolder
    print "[INFO] Parsing library Folder.."
    folders= listDir(rootDir)
    folders.sort()
    for folder in folders:
        if(folder!=diffFolder):
            for file in listFilesRecursive(folder):
                if(file[-4:]==".zim"):
                    print "Adding file "+file+" to library..."
                    localFileName= file[len(rootDir)+1:]
                    runCommand('kiwix-manage '+ libFile+' add '+file+' --zimPathToSave="" --url=http://download.kiwix.org/zim/'+localFileName+ '.meta4 origId= "" ')
    for file in listFilesRecursive(diffFolder):
            if(file[-4:]==".zim"):
                print "Adding file "+file+" to library..."
                localFileName= file[len(rootDir)+1:]
                runCommand('kiwix-manage '+ libFile+' add '+file+' --zimPathToSave="" --url=http://download.kiwix.org/zim/'+localFileName+ '.meta4 origId= '+file[:-15])



