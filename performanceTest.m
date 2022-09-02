% Runs the optimized and unoptimized algorithm on n data points, measures
% the time it takes for each and displays the time difference in a table.

maxNum = 3; % Change to test more data points (by powers of 10).
numData = 10.^(1:1:maxNum);

timeTakenOptimized = zeros(size(numData));
timeTakenNonOptimized = zeros(size(numData));

f = figure;

% Warms up the figure before testing
for i = 1:5
    f1 = filledLineChart(1:10, 1:10);
    delete(f1);
    f2 = filledLineChart(1:10, 1:10, 'Optimized', false);
    delete(f2);
end

% Tests each algorithm on increasing number of data points
for i = 1:maxNum
    disp("Running for " + numData(i) + " data points.");

    n = numData(i);
    x = 1:n;
    y = sin(linspace(0,4*pi,n)) + 10;

    tic;
    h1 = filledLineChart(x,y);
    drawnow;
    t1 = toc;

    delete(h1);
    timeTakenOptimized(i) = t1;

    tic;
    h2 = filledLineChart(x,y,'Optimized',false);
    drawnow;
    t2 = toc;

    delete(h2);
    timeTakenNonOptimized(i) = t2;
end

close(f);

% View the results in a table.
timeDiff = timeTakenNonOptimized - timeTakenOptimized;
T = table(numData', timeTakenNonOptimized', timeTakenOptimized', timeDiff');
T.Properties.VariableNames = {'Number of Data', 'Time (Non-Optimized)', ...
    'Time (Optimized)', 'Time Difference'};

disp(T)


