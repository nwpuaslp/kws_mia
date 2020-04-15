#!/usr/bin/env python2
# -*- coding: UTF-8 -*-
import argparse
import numpy as np
def read_scp(filename):
	f = open(filename,'r')
	filedict = {}
	for line in f.readlines():
		filedict[line.split()[0]]=(float)(line.split()[1])
	return filedict


def nol(x, axis=0):
	x = np.array(x)
	
	# 计算每行的最大值
	row_max = x.max(axis=axis)
	row_min = x.min(axis=axis)
    # 每行元素都需要减去对应的最大值，否则求exp(x)会溢出，导致inf情况
	s=(x-row_min)/(row_max-row_min)
	# 计算e的指数次幂
	return s.tolist()

def main(arg):
	score_src_dict = read_scp(arg.score)
	score = dict(zip(score_src_dict.keys(),nol(score_src_dict.values())))
	result = read_scp(arg.result)
	for key in score.keys():
		if result[key]-0 < 1e-5:
			score[key]=0
	for key in score.keys():
		print key+" "+str(score[key])
if __name__=='__main__':
	parser =argparse.ArgumentParser(description='process score and reuslt')
	parser.add_argument('score', help='score.txt')
	parser.add_argument('result', help='result.txt')

	FLAGS = parser.parse_args()

	main(FLAGS)

