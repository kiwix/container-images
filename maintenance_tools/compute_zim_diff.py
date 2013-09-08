#!/usr/bin/python
#Written by Kiran mathew Koshy

#Program for computing the diff files of different versions of the zim files.
#Loops through the current directory to obtain a list of folders.
#In each of these folders, obtain a list of zim files.
#Obtain list of existing diff files from the diff folder.
#Arrange each folder by date.(Obtained from the ZIM files - Oldest zim file in the folder)
#Starting from the second folder, for each zim file, search all previous folders for a similar file.
#If a similar file is obtained, check if the diff file exists for it or not.
#If it doesn't exist, create a diff_file, store it in the diff_folder.

import os
import subprocess 
import sys

#Important: since zimdiff is not part of zimlib yet, add the directory to zimdiff here :
zimdiffDir= "zimdiff"

#Location of kiwix library.
rootDir="/var/www/download.kiwix.org/zim/"

#Location of diff_folder:
diffFolderName="diff"
diffFolder=rootDir+'/'+diffFolderName

#Usage
def usage():
    print "Script to compute the diff_files between zim files in a directory using zimdiff"
    print "Usage: 'python compute_diff.py' "

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
def listZimFilesRecursive(dir):
    filelist=[]
    for file in listFiles(dir):
        if(file[-4:]==".zim"):
            filelist.append(file)
    for folder in listDir(dir):
        filelist.extend(listZimFilesRecursive(os.path.join(dir,folder)))
    return filelist

#Compares two zim files to see if they are of the same origin
def compareZimFiles(file1,file2):
    if(Title(file1)!=Title(file2)):
        return False
    if(Publisher(file1)!=Publisher(file2)):
        return False
    if(Creator(file1)!=Creator(file2)):
        return False
    return True

#Method to return the UUID of the zim file.
def UUID(filename):
    op=runCommand("zimdump "+filename+" -F")
    for i in range(0,len(op)):
        if(op[i][0:4]=="uuid"):
            return op[i][6:len(op[i])][:-1]
    return ""

#Method to return the Title of the ZIM file
def Title(filename):
    op=runCommand("zimdump -u M/Title -d "+filename)
    print filename
    return op[0]

#Method to return the publisher of the ZIM file
def Publisher(filename):
    op=runCommand("zimdump -u M/Publisher -d "+filename)
    return op[0]

#Method to return the Creator of the ZIM file:
def Creator(filename):
    op=runCommand("zimdump -u M/Creator -d "+filename)
    return op[0]

#Method to return the date of the file.
def date(filename):
    op=runCommand("zimdump -u M/Date -d "+filename)
    return op[0]

def isDiffFile(fileName):
    for file in listFiles(diffFolder):
        if(fileName==file):
            return True
    return False

#Method to return the name of the diff_file between two zim files
def diffFileName(start_file,end_file):
    if(compareZimFiles(start_file,end_file)!=True):
        return None
    start_uuid=UUID(start_file)
    end_date=date(end_file)
    return start_uuid+'_'+end_date+'.zim'


def createDiffFile(startFile,endFile):
    print zimdiffDir+' '+startFile+' '+endFile+' '+os.path.join(diffFolder,diffFileName(startFile,endFile))
    runCommand(zimdiffDir+' '+startFile+' '+endFile+' '+os.path.join(diffFolder,diffFileName(startFile,endFile)))

#Main function: 
if __name__ == "__main__":
    if(len(sys.argv)>=2):
    	if(sys.argv[1]=="--help" or sys.argv[1]=="-h"):
       	    usage()
            sys.exit(0)
    if(os.path.isdir(rootDir)==False):
        print "[ERROR] Library Folder does not exist."
        sys.exit(0)
    if(os.path.isdir(diffFolder)==False):
        print "[ERROR] Diff Folder does not exist."
        sys.exit(0)    
    print "[INFO] Library Folder: "+rootDir
    print "[INFO] Diff Folder: "+diffFolder
    print "[INFO] Parsing library Folder.."
    folders=listDir(rootDir)
    folders.sort()
    for i in range(0, len(folders)):
        if(folders[i]!=diffFolder):
            print "Searching folder "+folders[i]
            for file in listZimFilesRecursive(folders[i]):
                for j in range(0,i):
                    if(folders[j]!=diffFolder):
                        for oldFile in listZimFilesRecursive(folders[j]):
                            if(compareZimFiles(oldFile,file)==True):
                                print "Older version of "+file+" detected: "+oldFile
                                if(isDiffFile(diffFileName(oldFile,file))==False):
                                    createDiffFile(oldFile,file)
