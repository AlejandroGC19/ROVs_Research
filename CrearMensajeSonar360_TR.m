function [mensaje2601, sum_parcial]=CrearMensajeSonar360_TR(duration, sample_period, freq, n_samples, ganancia, transmit)

% MENSAJE 2601
duration_byte2=fix(duration/256);   %Division cogiendo el numero truncado sin decimal
duration_byte1=duration-256*duration_byte2;  %El resto hasta llegar a duracion

sample_period_byte2=fix(sample_period/256);
sample_period_byte1=sample_period-256*sample_period_byte2;

freq_byte2=fix(freq/256);
freq_byte1=freq-256*freq_byte2;

nsamples_byte2=fix(n_samples/256);
nsamples_byte1=n_samples-256*nsamples_byte2;

sum_parcial=214+ganancia+duration_byte1+duration_byte2+sample_period_byte1+sample_period_byte2+freq_byte1+freq_byte2+nsamples_byte1+nsamples_byte2+transmit;

mensaje2601=[66 82 14 0 41 10 0 0 1 ganancia 0 0 duration_byte1 duration_byte2 sample_period_byte1 sample_period_byte2 freq_byte1 freq_byte2 nsamples_byte1 nsamples_byte2 transmit 0 0 0]; %895 para head angle 0
end