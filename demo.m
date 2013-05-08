%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%The Comparison Between Different Methods for Depth Upampling 
%   Description:
%       The code compares different depth upsampling methods. More information can be found in Readme.txt
%Code Author:
%   Liu Junyi, Zhejiang University
%   version 1: June 2012
%   version 2: May 2013
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all;
close all;
clc;

%% Read data

Depth = imread('.\data\plastic\GroundTruth.png');
Color = imread('.\data\plastic\Color.png');

%% Trim data if needed
ColorSection = Color(381:420,231:250,:);
DepthSection = Depth(381:420,231:250);

%% assert 
if((size(DepthSection,1)~=size(ColorSection,1))||size(DepthSection,2)~=size(ColorSection,2))
    error('The depth section size must be the same as the color section');
end

Height = size(DepthSection,1);
Width = size(DepthSection,2);

%% Set Parameters

% Scaling Factor
Interval = 5;             % Down-sample factor

% BilateralFilter 
BF_sigma_w = 3;	 % range sigma
BF_sigma_c = 10;	 % spatial sigma
BF_window = 8;	   	 % window size - radius
BF_method = 2;		 % The method of bilateral filter  1: original bilateral filter 2: fast bilateral filter

% AD Parameters
AD_sigma = 10;


% MRF Parameters
MRF_sigma = 10;       % The parameter for the gaussion kernel in the smoothness term: exp(-D^2/(2*MRF_sigma^2))
MRF_alpha = 1;       % The balance factor between data term and smoothness term: DataEnergy+alpha*smoothnessEnergy
MRF_method = 2;	   	 % The method to solve MRF

% MRF Parameters based on Tensor
MRF_Tensor_lamda = 1;         % The balance factor between IxIy and RGB in tensor: [Ix Iy lamda*R lamda*G lamda*B]'
MRF_Tensor_sigma = 0.2;       % The parameter for the gaussion kernel in the smoothness term: exp(-D^2/(2*LSLSTensor_sigma^2))
MRF_Tensor_alpha = 1;         % The balance factor between data term and smoothness term: DataEnergy+alpha*smoothnessEnergy
MRF_Tensor_method = 1;		% The method to solve MRF

% %YangIteration  
% YI_sigma_w = 3;
% YI_sigma_c = 10;
% YI_window = 5;
% YIDepthInteval = 20;          % Depth slice interal
% YIIterativeTime = 3;




%% Generate the depth map in low resolution
SamplePoints = zeros(Height,Width);
StartPoint = floor(Interval/2) + 1;
SamplePoints(StartPoint:Interval:end,StartPoint:Interval:end) = 1;                 
SampleDepth = SamplePoints.*double(DepthSection);
LowResDepth = DepthSection(StartPoint:Interval:end,StartPoint:Interval:end);      %Sample the low resolution Depth Map
HighResDepth = imresize(LowResDepth,Interval);                              %Interpolating to the Normal size


%% Choose models
runBilateralFilter      =   false;
runAnisotropicDiffusion = 	false;  
runMRF        			=   true;
runMRFTensor	        =   false;
runYangIteration		=   false;

%% Let us begin!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%   Bilateral Filter                
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(runBilateralFilter)
	tic
    if(BF_method == 1)
		BFResult = BilateralFilter(ColorSection,SampleDepth,BF_sigma_w,BF_sigma_c,BF_window);
	elseif(BF_method == 2)
		BFResult = FastBilateralFilter(SampleDepth,double(rgb2gray(ColorSection)),...
                                        0,255,BF_sigma_w,BF_sigma_c);
	end
	fprintf('$BF:Total running time is %.5f s\n',toc)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%   Anisotropic Diffusion         
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% if(runAnisotropicDiffusion)
%     
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Original MRF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(runMRF)
    tic
    if(MRF_method == 1)
        MRFResult = MRFUpsamplingEq(ColorSection,SampleDepth,MRF_sigma,MRF_alpha);
    elseif (MRF_method == 2)
        MRFResult = MRFUpsamplingCG(ColorSection,SampleDepth,MRF_sigma,MRF_alpha);
    elseif (MRF_method == 3)
        MRFResult = MRFUpsamplingGC(ColorSection,SampleDepth,MRF_sigma,MRF_alpha);
    end
    fprintf('$MRF:Total running time is %.5f s\n',toc)
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%       Yang's Iterative Depth Refinement           %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% if(runYangIteration)
%     YIResult=YangIteration(ColorSection,NLRDepth,Height,Width,YI_sigma_w,YI_sigma_c,YI_window,YIDepthInteval,YIIterativeTime);
% end




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% MRF + Tensor; Solve a Large Sparse Linear System  %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% if(runLSLSTensor)
%     %T is the data structure to store the tensors
%     T=Tensor(ColorSection,LSLSTensor_lamda,Height,Width);  % Tip: the correction diag matrix in the tensor has effects on the result
%     LSLSTensorResult=LSLSTensor(T,SampleDepth,SamplePoints,Height,Width,LSLSTensor_sigma,LSLSTensor_alpha);  
% end


%% It's the time to see the results
figure;
subplot(2,2,1);imshow(uint8(ColorSection));title('Color Image');axis off
subplot(2,2,2);imshow(DepthSection,[0 255]);title('Ground Truth');axis off
subplot(2,2,3);imshow(SampleDepth,[0 255]);title('Downsampled Depth Map');axis off
subplot(2,2,4);imshow(HighResDepth,[0 255]);title('Depth Map by interpolation');axis off
if(runAnisotropicDiffusion)
    figure;
    imshow(uint8(reshape(full(AP_GCPResult),Height,Width)),[0 255]);axis off
    title('Adaptive Propagation from GCPs')
    imwrite(uint8(reshape(full(AP_GCPResult),Height,Width)),'AP_GCP.png','png')
end
if(runBilateralFilter)
    figure;
    imshow(BFResult,[0 255]);axis off
    title('Bilateral Filter')
%     imwrite(uint8(BFResult),'./result/BilateralFilter.png','png')
end
if(runYangIteration)
    figure;
    imshow(YIResult,[0 255]);axis off;
    title('Yang Iterative Depth Refinement')
    imwrite(uint8(YIResult),'YangIteration.png','png')
end
if(runMRF)
    figure;
    imshow(uint8(MRFResult),[0 255]);axis off
    title('Original MRF')
%     imwrite(uint8(MRFResult),'./result/MRFUpsample.png','png')
end
if(runMRFTensor)
    figure;
    imshow(uint8(reshape(full(LSLSTensorResult),Height,Width)));axis off
    title('MRF + Tensor')
    imwrite(uint8(reshape(full(LSLSTensorResult),Height,Width)),'LSLSTensor.png','png')
end

% The results of some other methods cannot be seen here, please refer to the directory - "MRF2.1","Robust_PN" and"HDFilter"

%% Quantative evaluation

% QLSLSOriginal=reshape(full(LSLSOriginalResult),Height,Width);
% QLSLSTensor=reshape(full(LSLSTensorResult),Height,Width);
% Q1=abs(QLSLSOriginal-DepthSection);
% Q2=abs(QLSLSTensor-DepthSection);
% Q1=Q1(2:Height-1,2:Width-1);
% Q2=Q2(2:Height-1,2:Width-1);
% Q1_result=sqrt(sum(Q1(:))/(78*78));
% Q2_result=sqrt(sum(Q2(:))/(78*78));
%To be filled... 

