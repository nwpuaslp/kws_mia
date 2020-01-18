#!/usr/bin/env python
'''
@Author: your name
@Date: 2020-01-17 09:06:35
@LastEditTime : 2020-01-17 19:40:15
@LastEditors  : Please set LastEditors
@Description: In User Settings Edit
@FilePath: /yao_workspace/kws_mia/local/run_fst.py
'''

import numpy as np
import argparse
import sys
class edge:
    def __init__(self, cur_state, to_state, isymbol, osymbol):
        self.cur_state=cur_state
        self.to_state=to_state
        self.isymbol=isymbol
        self.osymbol=osymbol
    
    def getToState(self):
        return self.to_state

class state:
    def __init__(self):
        self.oedge=list()
        self.inputSymbol=list()
    def addEdge(self,edge):
        self.oedge.append(edge)
        self.inputSymbol.append(int(edge.isymbol))
    def hasOut(self,inputId):
        for i in self.inputSymbol:
            if i== inputId:
                return True
        return False
    
    def getOutput(self, inputId):
        pos = self.inputSymbol.index(inputId)
        if pos == -1:
            sys.exit(1)
        return self.oedge[pos].to_state, self.oedge[pos].osymbol

class path:
    def __init__(self,result=list(),post=1.0,cur_state=0,kws=False):
        self.result=result
        self.post=post
        self.cur_state=cur_state
        self.kws=kws
class stateMachine:
    def __init__(self, stateFile):
        self.stateList=list()
        f = open(stateFile,"r")
        self.endState=dict()
        for line in f.readlines():
            if len(line.split())==2:
                self.endState[line.split()[0]]=float(line.split()[1])
                continue
            if  len(self.stateList) <= int(line.split()[0]):
                new_state = state()
                new_state.addEdge(edge(line.split()[0], line.split()[1], line.split()[2], line.split()[3]))
                
                self.stateList.append(new_state)
            else:
                self.stateList[int(line.split()[0])].addEdge(edge(line.split()[0], line.split()[1], line.split()[2], line.split()[3]))
        f.close
        self.name=list()
        self.cur_state=0
        self.pathList=list()
        self.beamsize=1
        self.frame_num=0
    
    def runFst(self, postFile):
        f = open(postFile, "r")
        self.postList = dict()
        i=0
        for line in f.readlines():
            # if i > 3 :
            #     sys.exit()
            self.runFst_oneLine(line)
            i = i+1
        return self.postList

    def runFst_oneLine(self,line):
        if(len(line.split())==2):
            self.name=line.split()[0]
            self.cur_state=0
            self.post=0.0
            self.pathList=list()
            self.pathList.append(path())
            self.frame_num=0

        elif(len(line.split())==10):
            self.frame_num=self.frame_num+1
            post=[ np.exp(float(x)) for x in line.split() ]
            post= post/np.sum(post)
            # print post
            numpath = len(self.pathList)
            for j in range(numpath):
                thisPath = self.pathList.pop(0)
                for i in range(len(post)):
                    thisState=self.stateList[int(thisPath.cur_state)]
                    if thisState.hasOut(i):
                        newpath = list(thisPath.result)
                        [outState, outSymbol] = thisState.getOutput(i)
                        # print "inputi"+str(i)
                        # print "outsymbol"+str(outSymbol)
                        newpath.append(outSymbol)
                        if thisPath.kws==True or outSymbol==1:
                            # if int(outState)==int(thisPath.cur_state):
                            #     self.pathList.append(path(result=newpath,post=thisPath.post,cur_state=outState,kws=True))
                            # else:
                            self.pathList.append(path(result=newpath,post=np.power(thisPath.post*post[i],0.5),cur_state=outState,kws=True))
                        else:
                            # print thisPath.cur_state
                            # print outState
                            # print thisPath.post
                            # if int(outState)==int(thisPath.cur_state):
                            #     self.pathList.append(path(result=newpath,post=thisPath.post,cur_state=outState,kws=False))
                            # else:
                            #     print thisPath.post*post[i]
                            self.pathList.append(path(result=newpath,post=np.power(thisPath.post*post[i],0.5),cur_state=outState,kws=False))
            self.pathList.sort(key=lambda a: a.post ,reverse=True)
            # print self.pathList[0].post
            # print self.pathList[0].cur_state
            self.pathList=self.pathList[:self.beamsize]
            # print "asdfasdf"
        elif(len(line.split())==11):
            for i in range(len(self.pathList)):
                if self.pathList[i].kws:
                    self.post=self.post+self.pathList[i].post
            print self.pathList[0].post
            self.postList[self.name]=self.post
    
    def printFst(self):
        for i in range(len(self.stateList)):
            print "state"+str(i)
            print self.stateList[i].inputSymbol


    
if __name__=='__main__':
    parser = argparse.ArgumentParser(description="decode kws output")
    parser.add_argument('Fst_file',help='Fst file')
    parser.add_argument('bnf_file',help='output of network')
    
    FLAGS = parser.parse_args()

    stateM = stateMachine(FLAGS.Fst_file)
    # stateM.printFst()
    result = stateM.runFst(FLAGS.bnf_file)

    print result
                

        
    