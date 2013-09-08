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

#zimdiff Binary :
global zimdiff
#Location of kiwix library.
global rootDir
#Location of diff_folder:
global diffFolder


#Executes a command and returns the output
def runCommand(command):
    p=subprocess.Popen(command,shell=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    op=[]
    for line in p.stdout.readlines():
        op.append(line)
    return op

#Check if zimdiff is installed or not.
#Runs a shell command 'zimdiff'
#IF the words 'not ' and 'found' are present in the output, and if the output is a single line, then zimdiff is not present in the system.
def checkZimdiff():
    op=runCommand("zimdiff")
    nt=False
    found=False
    if(len(op)==1):
        for word in op[0].split():
            if(word=="not"):
                nt=True
            if(word=="found"):
                found=True
        if(nt and found):
            return False
    return True

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
        if(os.path.join(dir,folder)!=diffFolder):
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
    if(len(op)!=0):
        return op[0]
    else:
        return ""

#Method to return the publisher of the ZIM file
def Publisher(filename):
    op=runCommand("zimdump -u M/Publisher -d "+filename)
    if(len(op)!=0):
        return op[0]
    else:
        return ""

#Method to return the Creator of the ZIM file:
def Creator(filename):
    op=runCommand("zimdump -u M/Creator -d "+filename)
    if(len(op)!=0):
        return op[0]
    else:
        return ""

#Method to return the date of the file.
def date(filename):
    op=runCommand("zimdump -u M/Date -d "+filename)
    if(len(op)!=0):
        return op[0]
    else:
        return ""

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
    #print zimdiff+' '+startFile+' '+endFile+' '+os.path.join(diffFolder,diffFileName(startFile,endFile))
    runCommand(zimdiff+' '+startFile+' '+endFile+' '+os.path.join(diffFolder,diffFileName(startFile,endFile)))


#Usage
def usage():
    print "Script to compute the diff_files between zim files in a directory using zimdiff"
    print "Usage: 'python compute_diff.py' --dir <Library Directory> --diff <diff Folder> --zimdiff <zimdiff_dir> "
    print "Zimdiff directory is required if zimdiff is not installed in the system"

#Main function: 
if __name__ == "__main__":
    global zimdiff
    global rootDir
    global diffFolder
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
                rootDir=sys.argv[i+1]
        if(sys.argv[i]=="--diff"):
            if(i<(len(sys.argv)-1)):
                diffFolder=sys.argv[i+1]
        if(sys.argv[i]=="--zimdiff"):
            if(i<(len(sys.argv)-1)):
                zimdiff=sys.argv[i+1]
    
    #If the zimdiff variable does not exist:
    if(('rootDir' in globals())==False):
        print "Not enough arguments (root directory)"
        usage()
        sys.exit(0)
      
    #If the zimdiff variable does not exist:
    if(('diffFolder' in globals())==False):
        print "Not enough arguments (diff Folder)"
        usage()
        sys.exit(0)

    #If the zimdiff variable does not exist:
    if(('zimdiff' in globals())==False):
        if(checkZimdiff()):
            zimdiff="zimdiff"  
        else:
            print "Not enough arguments(zimdiff binary)"
            usage()
            sys.exit(0)
       
    if(os.path.isdir(rootDir)==False):
        print "[ERROR] Library Folder does not exist."
        sys.exit(0)
    if(os.path.isdir(diffFolder)==False):
        print "[ERROR] Diff Folder does not exist."
        sys.exit(0)    
    if(checkZimdiff()==False):
        if(os.path.isfile(zimdiff)==False):
            print "[ERROR] zimdiff binary does not exist."
            sys.exit(0)    
    rootDir=os.path.abspath(rootDir)
    diffFolder=os.path.abspath(diffFolder)
    print "[INFO] Library Folder: "+rootDir
    print "[INFO] Diff Folder: "+diffFolder
    print "[INFO] Parsing library Folder.."
    files=listZimFilesRecursive(rootDir)
    files.sort(key = date)
    for i in range(0, len(files)):
        for j in range(0,i):
            if(compareZimFiles(files[j],files[i])==True):
                print "Older version of "+files[i]+" detected: "+files[j]
                if(isDiffFile(diffFileName(files[j],files[i]))==False):
                    createDiffFile(files[j],files[i])
