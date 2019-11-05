%% Generates a raised cosine filter
%%
%% Inputs
%%
%% fs - sampling rate
%% alpha - desired roll-off factor (valid range: 0 - 1)
%%
%% Output
%% 
%% output - raised cosine filter
%%
%%
%% Licensed under Creative Commons
%%
%% Courtosy of:
%%
%% http://www.dsplog.com/db-install/wp-content/uploads/2008/05/raised_cosine_filter.m
%%
function output = GenerateRaisedCosine(fs, alpha)

fs_step = 1 / fs;
sincNum = sin(pi*[-fs:fs_step:fs]);
sincDen = (pi*[-fs:fs_step:fs]);
sincDenZero = find(abs(sincDen) < 10^-10);
sincOp = sincNum./sincDen;
sincOp(sincDenZero) = 1;

cosNum = cos(alpha*pi*[-fs:fs_step:fs]);
cosDen = (1-(2*alpha*[-fs:fs_step:fs]).^2);
cosDenZero = find(abs(cosDen)<10^-10);
cosOp = cosNum./cosDen;
cosOp(cosDenZero) = pi/4;

output = sincOp.*cosOp;