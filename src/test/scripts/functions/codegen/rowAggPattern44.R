#-------------------------------------------------------------
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# 
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#-------------------------------------------------------------
args <- commandArgs(TRUE)
library("Matrix")
library("matrixStats") 

imgSize=8
numImg=16
numChannels=4
poolSize1=imgSize*imgSize
poolSize2=1
stride=1
pad=0

X = matrix(seq(1, numImg*numChannels*imgSize*imgSize), numImg, numChannels*imgSize*imgSize, byrow=TRUE)
X = X - rowMeans(X)

pad_image <- function(img, Hin, Win, padh, padw){
  C = nrow(img)
  img_padded = matrix(0, C, (Hin+2*padh)*(Win+2*padw))  # zeros
  for (c in 1:C) {
    img_slice = matrix(img[c,], Hin, Win, byrow=TRUE)  # depth slice C reshaped
    img_padded_slice = matrix(0, Hin+2*padh, Win+2*padw)
    img_padded_slice[(padh+1):(padh+Hin), (padw+1):(padw+Win)] = img_slice
    img_padded[c,] = matrix(t(img_padded_slice), 1, (Hin+2*padh)*(Win+2*padw))  # reshape
  }
  img_padded
}

im2col <- function(img, Hin, Win, Hf, Wf, strideh, stridew) {
  C = nrow(img)
  Hout = as.integer((Hin - Hf) / strideh + 1)
  Wout = as.integer((Win - Wf) / stridew + 1)

  img_cols = matrix(0, C*Hf*Wf, Hout*Wout, byrow=TRUE)  # zeros
  for (hout in 1:Hout) {  # all output rows
    hin = (hout-1) * strideh + 1
    for (wout in 1:Wout) {  # all output columns
      win = (wout-1) * stridew + 1
      # Extract a local patch of the input image corresponding spatially to the filter sizes.
      img_patch = matrix(0, C, Hf*Wf, byrow=TRUE)  # zeros
      for (c in 1:C) {  # all channels
        img_slice = matrix(img[c,], Hin, Win, byrow=TRUE)  # reshape
        img_patch[c,] = matrix(t(img_slice[hin:(hin+Hf-1), win:(win+Wf-1)]), 1, Hf*Wf)
      }
      img_cols[,(hout-1)*Wout + wout] = matrix(t(img_patch), C*Hf*Wf, 1)  # reshape
    }
  }
  img_cols
}

max_pool <- function(X, N, C, Hin, Win, Hf, Wf,
                   strideh, stridew) {
  Hout = as.integer((Hin - Hf) / strideh + 1)
  Wout = as.integer((Win - Wf) / stridew + 1)

  # Create output volume
  out = matrix(0, N, C*Hout*Wout, byrow=TRUE)

  # Max pooling - im2col implementation
  for (n in 1:N) {  # all examples
    img = matrix(X[n,], C, Hin*Win, byrow=TRUE)  # reshape
    img_maxes = matrix(0, C, Hout*Wout, byrow=TRUE)  # zeros

    for (c in 1:C) {  # all channels
      # Extract local image slice patches into columns with im2col, of shape (Hf*Wf, Hout*Wout)
      img_slice_cols = im2col(matrix(t(img[c,]), 1, Hin*Win) , Hin, Win, Hf, Wf, strideh, stridew)

      # Max pooling on patches
      img_maxes[c,] = colMaxs(img_slice_cols)
    }

    out[n,] = matrix(t(img_maxes), 1, C*Hout*Wout)
  }
  
  out
}

R = max_pool(X, numImg, numChannels, imgSize*imgSize, 1, poolSize1, poolSize2, stride, stride)
R = R + 7;

writeMM(as(R,"CsparseMatrix"), paste(args[2], "S", sep=""))
