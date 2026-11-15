% item2b_diagnostics.m -- spectrum, growth check and sequence analysis of the weak-grid distortion (SCR 0 / 20 / 5). Outputs are in ../results/item2b_diagnostics_console.txt
% (The two diagnostic scripts were run as pasted in the chat: a spectrum/THD-by-window script, then a sequence-component script with controller parameter dump.)
% Core of the sequence analysis: F = fft(Y.*hann)/n at the bin of each harmonic h; with a = exp(2j*pi/3)
%   pos = |(Xa + a*Xb + a^2*Xc)/3|, neg = |(Xa + a^2*Xb + a*Xc)/3|, zero = |(Xa+Xb+Xc)/3|, relative to the positive-sequence fundamental.
