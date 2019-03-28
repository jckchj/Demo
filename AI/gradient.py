#coding=utf-8
##
#Calculate the hypothesis h = X * theta
#Calculate the loss = h - y and maybe the squared cost (loss^2)/2m
#Calculate the gradient = X' * loss / m
#Update the parameters theta = theta - alpha * gradient
###
import numpy as np
from numpy import *
import random
def loadDataSet(filename):
    numFeat = len(open(filename).readline().split(','))-1
    datMat = []; labelMat = []
    fr = open(filename)
    for line in fr.readlines():
        lineArr = []
        curLine = line.strip().split(',')
        for i in range(numFeat):
            lineArr.append(float(curLine[i]))
        datMat.append(lineArr)
        labelMat.append(float(curLine[-1]))
    return datMat,labelMat

#x为自变量训练集，y为自变量对应的因变量训练集；theta为待求解的权重值，需要事先进行初始化；alpha是学习率；m为样本总数；maxIterations为最大迭代次数；
def batchGradientDescent(x, y, theta, alpha, m, maxIterations):
    xTrains = x.transpose()   #x 转置
    for i in range(0, maxIterations):
        hypothesis = np.dot(x, theta) #矩阵乘法，https://migege.com/post/matrix-multiplication-in-numpy 计算f(x(k))
        loss = hypothesis - y
        #print(loss)
        #print(m)
        #print(type(loss))
        # avg cost per example (the 2 in 2*m doesn't really matter here.
        # But to be consistent with the gradient, I include it)
        cost = np.sum(loss ** 2) / (2 * m)
        print("Iteration %d | Cost: %f" % (i, cost))
        # avg gradient per example
        gradient = np.dot(xTrains, loss) / m  ##梯度
        #print("gradinet is ",gradient)
        # update
        theta = theta - alpha * gradient #x(k+1)
        #print("theta is ",theta)
    return theta



xArr,yArr = loadDataSet('gmvusers3.csv')
xArr1 = asarray(xArr)
yArr1 = asarray(yArr)
#print("xArr is ",asarray(xArr))
#print("yArr is ",asarray(yArr))
#print(asarray(xArr).dtype)
#print(asarray(yArr).dtype)
m, n = np.shape(xArr1)
print("m %d | n %d" %(m,n))
numIterations= 10000
alpha = 0.00000001
theta = [1,1]  #Return a new array of given shape and type, filled with ones. 初始值。
theta = batchGradientDescent(xArr1, yArr1, theta, alpha, m, numIterations)
print(theta)
####


# gen 100 points with a bias of 25 and 10 variance as a bit of noise
#x, y = genData(100, 25, 10)
#print(x)
#print(y)
#print(x.dtype)
#print(y.dtype)
#m, n = np.shape(x)
#numIterations= 100000
#alpha = 0.0001
#theta = np.ones(n)
#theta = batchGradientDescent(x, y, theta, alpha, m, numIterations)
#print(theta)


import matplotlib.pyplot as plt
fig = plt.figure()
ax = fig.add_subplot(111)
ax.plot(yArr1,'go')

xCopy = xArr1.copy()
xCopy.sort(0)
yHat=xCopy*theta
ax.plot(xCopy[:,1],yHat)
plt.show()
print(yArr1)
print(yHat)
print(corrcoef(yHat.T,yArr1))