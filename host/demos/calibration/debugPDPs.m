%% Plot pdpStore from calTimingPhaseRx.m
figure(1); clf;
iadc = 1;
expType = 2;
iters = [1]
ntimes = 50;
cols = 'mrgb';
subplot(2,1,1);
a = zeros(0,0);
for iter = iters
    for itimes=1:ntimes
        l = pdpStore(iadc, expType, iter, itimes, :);
        l = reshape(l, 1, []);
        plot(mag2db(abs(l)), cols(iadc));
        ylim([40 100]); grid on;
        pause(0.1);
        
        [val,pos] = max(l);
        a = [a angle(val)];
    end
end
subplot(2,1,2);
plot(a, cols(iadc));
clear a cols expType iter itimes l niter ntimes pos rxIndex

%% Plot pdpStore from calTimingPhaseTx.m
figure(1); clf;
txIndex = 1;
expType = 1;
iters = [1];
ntimes = 49;
cols = 'mrgb';
subplot(2,1,1);
a = zeros(0,0);
for iter=iters
    for itimes=1:ntimes
        l = pdpStore(txIndex, expType, iter, itimes, :);
        l = reshape(l, 1, []);
        l = mag2db(abs(l));
        plot(l, cols(txIndex));
        ylim([40 100]); grid on;
        pause(0.01);
        
        [~,pos] = max(l);
        a = [a pos];
    end
end
subplot(2,1,2);
plot(a, cols(txIndex));
clear a cols expType iter itimes l niter ntimes pos txIndex

%% Plot pdpStore from sounderADC.m
figure(1); clf;
iadc = 4;
expType = 1;
iter = 1;
ntimes = 100;
cols = ['m-.'; 'm-*'; 'r-.'; 'r-*'; 'b-.'; 'g-.'; 'b-*'; 'g-*'; ];
subplot(3,1,1);
a = zeros(0,0);
for itimes = 1:ntimes
    
        l = pdpStore(iadc, expType, iter, itimes, :);
        l = reshape(l, 1, []);
        plot(mag2db(abs(l)), cols(iadc,:));
        ylim([40 100]); grid on;
        pause(0.05);
        
        [val,pos] = max(l);
        a = [a val];

end
subplot(3,1,2);
plot(mag2db(abs(a)), cols(iadc,:));
grid on; grid minor;

subplot(3,1,3);
plot(angle(a), cols(iadc,:));
grid on; grid minor;
clear a cols expType iter itimes l niter ntimes pos rxIndex

%% Plot pdpStore from calDelayDAC.m
figure(1); clf;
idac = 1;
expType = 1;
iters = [1];
ntimes = 50;
cols = ['m-*'; 'm-o'; 'r-o'; 'r-*'; 'g-o'; 'b-o'; 'g-*'; 'b-*'; ]; % Based on the mapping from ich to idac
subplot(3,1,1);
a = zeros(0,0);
b = zeros(0,0);
for iter=iters
    for itimes=1:ntimes
        l = pdpStore(idac, expType, iter, itimes, :);
        l = reshape(l, 1, []);
        l = mag2db(abs(l));
        plot(l, cols(idac,1));
        ylim([40 100]); grid on;
        pause(0.1);
        

        [val,pos] = max(l);
        a = [a val];
        b = [b pos];
    end
end

subplot(3,1,2);
plot(a, cols(idac,:));
title('Val');
subplot(3,1,3);
plot(b, cols(idac,:));
title('Pos');
clear a cols expType iter itimes l niter ntimes pos txIndex