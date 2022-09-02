classdef filledLineChart < matlab.graphics.chartcontainer.ChartContainer
    % filledLineChart plots a line chart with a filled gradient using
    % explicit triangulation for optimization.
    % 
    % filledLineChart(XData, YData) creates one or more lines each with
    % their own gradient using an optimized algorithm. Each column of
    % YData represents a new line.
    %
    % filledLineChart(____, Name, Value) specifies additional options for
    % the component using one or more name-value pair arguments. Specify
    % the options after all other input arguments.
    % 
    % filledLineChart(target,___) plots into target instead of GCF.
    %
    % f = filledLineChart(___) returns the filledLineChart object. Use f to
    % modify properties of the component after creating it.

    % Copyright 2022 The MathWorks, Inc.
    properties
        XData (:,1) {mustBeNumeric} = []
        YData (:,:) {mustBeNumeric, mustBeNonnegative} = []

        Title (1,:) string = ''
        Subtitle (1,:) string = ''
        XLabel (1,:) string = ''
        YLabel (1,:) string = ''

        ColorOrder (:, 3) {validatecolor(ColorOrder, 'multiple')} = lines(7)

        Grid {mustBeValidGrid} = 'off'
        LineWidth (1,1) double {mustBePositive} = 2
        LineStyle (1,:) char {mustBeMember(LineStyle, {'-', '--', ':', '-.'})} = '-'

        Optimized (1,1) matlab.lang.OnOffSwitchState = true
        ShowTriangulation (1,1) matlab.lang.OnOffSwitchState = false
        LegendVisible (1,1) matlab.lang.OnOffSwitchState = false
        LegendLabels (1,:) string = 'data1'
    end

    properties(Access = protected, Transient, NonCopyable)
        PatchObject (1,:) matlab.graphics.primitive.Patch

        % Need line objects to control the stylistic properties of the line
        % itself (and not the gradient)
        PlotLineArray (:,1) matlab.graphics.chart.primitive.Line
    end

    methods
        function obj = filledLineChart(varargin)
            % Initialize list of arguments
            args = varargin;
            leadingArgs = cell(0);
            
            % Check if the first input argument is a graphics object to use as parent.
            if ~isempty(args) && isa(args{1},'matlab.graphics.Graphics')
                % filledLineChart(parent, ___)
                leadingArgs = args(1);
                args = args(2:end);
            end

            if ~isempty(args)
                if numel(args) >= 2 && mod(numel(args), 2) == 0 && ...
                        isnumeric(args{1}) && isnumeric(args{2})
                    % filledLineChart(XData, YData)
                    % filledLineChart(XData, YData, Name, Value)

                    x = args{1};
                    y = args{2};

                    % Validate that x is a vector
                    if isvector(x)
                        x = x(:);
                    else
                        error("XData must be a vector.");
                    end

                    % Validate that y is a column vector
                    if isvector(y)
                        y = y(:);
                    end

                    % Validate that there are the same number of y-coordinates per
                    % line as the number of x-coordinates
                    if size(y, 1) ~= size(x, 1)
                        error("Must have the same number of y-coordinates" + ...
                            " per line as the number of x-coordinates.");
                    end

                    leadingArgs = [leadingArgs {'XData', x, 'YData', y}];
                    args = args(3:end); 
                else
                    error("Invalid input.")
                end
            end

            % Combine positional arguments with name/value pairs.
            args = [leadingArgs args];
            
            % Call superclass constructor method
            obj@matlab.graphics.chartcontainer.ChartContainer(args{:});
        end

        function set.Grid(obj, value)
            obj.Grid = mustBeValidGrid(value);
        end

        function set.XLabel(obj, label)
            xlabel(getAxes(obj), label);
        end

        function lbl = get.XLabel(obj)
            ax = getAxes(obj);
            lbl = ax.XLabel.String;
        end

        function set.YLabel(obj, label)
            ylabel(getAxes(obj), label);
        end

        function lbl = get.YLabel(obj)
            ax = getAxes(obj);
            lbl = ax.YLabel.String;
        end

        function set.Title(obj, t)
            title(getAxes(obj), t);
        end

        function t = get.Title(obj)
            ax = getAxes(obj);
            t = ax.Title.String;
        end

        function set.Subtitle(obj, sub)
            subtitle(getAxes(obj), sub);
        end

        function sub = get.Subtitle(obj)
            ax = getAxes(obj);
            sub = ax.Subtitle.String;
        end

        function set.ColorOrder(obj, c)
            colororder(getAxes(obj), c);
        end

        function c = get.ColorOrder(obj)
            ax = getAxes(obj);
            c = ax.ColorOrder;
        end
    end
        

    methods(Access = protected)
        function setup(obj)
            % Create the axes
            ax = getAxes(obj);
            ax.Box = 'on';

            % Create graphics objects
            obj.PatchObject = patch(ax, NaN, NaN, 'k');
            obj.PatchObject.FaceAlpha = 'interp';
            ax.XLimitMethod = 'tight';
        end

        function update(obj)
            ax = getAxes(obj);

            % Number of columns indicate the number of lines needed to plot
            ncols = size(obj.YData, 2);

            if obj.Optimized
                plotMultipleOptimizedPatch(obj, ncols);
            else
                plotMultiplePatch(obj, ncols);
            end

            % For one line, only need to designate a single color.
            if ncols <= 1
                obj.PatchObject.FaceColor = getColors(1, obj.ColorOrder);
            elseif ncols > 1
                obj.PatchObject.FaceColor = 'flat';
            end

            % Display the triangulation by showing the patch outline
            if obj.ShowTriangulation
                obj.PatchObject.EdgeColor = 'black';
            else
                obj.PatchObject.EdgeColor = 'none';
            end

            % Set grid lines
            if isequal(obj.Grid, 'columns')
                ax.XGrid = 'on';
                ax.YGrid = 'off';
            elseif isequal(obj.Grid, 'rows')
                ax.XGrid = 'off';
                ax.YGrid = 'on';
            else
                grid(ax, obj.Grid);
            end

            % Create extra lines as needed
            p = obj.PlotLineArray;
            linesNeeded = size(obj.YData, 2);
            linesHave = numel(p);
            
            % Specify the series index for the color order
            for i = linesHave+1:linesNeeded
                p(i) = matlab.graphics.chart.primitive.Line('Parent', ax, 'SeriesIndex', i);
            end

            % Update the legend labels - if insufficient, label the rest of
            % the lines as data + line number by default
            numLabels = numel(obj.LegendLabels);
            if numLabels ~= ncols
                obj.LegendLabels = [obj.LegendLabels ("data" + (numLabels+1:ncols))];
            end

            % Sort the lines based on the sorted YData, while YData still
            % remains the same as the user input.
            sortedYData = obj.YData;
            if ~isempty(obj.YData)
                sortedYData = sortLines(obj.YData);
            end

            % Update the lines
            for i = 1:linesNeeded
                p(i).XData = obj.XData;
                p(i).YData = sortedYData(:,i);
                p(i).LineStyle = obj.LineStyle;
                p(i).LineWidth = obj.LineWidth;
                p(i).DisplayName = obj.LegendLabels(i);
            end

            % Delete unneeded lines
            delete(p((linesNeeded+1):numel(p)))
            obj.PlotLineArray = p(1:linesNeeded);
 
            % Only display the legend for the lines, not the patch object
            if obj.LegendVisible
                legend(ax, obj.PlotLineArray);
            else
                legend(ax, 'off');
            end

        end
    end
end

function value = mustBeValidGrid(value)
    if islogical(value) && isscalar(value)
        if value 
            value = 'on';
        else
            value = 'off';
        end
    end
    value = string(lower(value));
    mustBeMember(value, {'on', 'off', 'columns', 'rows'})
end

function plotMultiplePatch(obj, numLines)
    x = repmat([obj.XData; flip(obj.XData)], numLines, 1);

    sortedYData = obj.YData;
    if ~isempty(obj.YData)
        sortedYData = sortLines(obj.YData);
    end
    y = [sortedYData; zeros(size(sortedYData))];

    obj.PatchObject.XData = x;
    obj.PatchObject.YData = y;

    c = getColors(numLines, obj.ColorOrder);
    
    % Each column in YData needs to be scaled from maximum opacity to
    % fully-transparent. Find the maximum value from each column, and then
    % shift each column so they all start at the same maximum value.
    y_scaled = scaleYData(sortedYData);
    y_scaled = [y_scaled; zeros(size(obj.YData))];

    obj.PatchObject.FaceVertexAlphaData = y_scaled(:);
    obj.PatchObject.FaceVertexCData = c;
end

function plotMultipleOptimizedPatch(obj, numLines)
    n = numel(obj.XData);
    ind = (1:(2*n)-2)'+[0 1 2];
    x = [obj.XData obj.XData]';

    % Sort the lines based on which gradient will overlap the others (the
    % line with the larger y-values). Plot them in descending order so that
    % the smaller gradients are on top of the larger ones, and the hue of
    % the lower colors isn't affected.
    sortedYData = obj.YData;
    if ~isempty(obj.YData)
        sortedYData = sortLines(obj.YData);
    end
    y = [sortedYData(:) zeros(size(sortedYData(:)))]';

    % Must scale YData to find the appropriate alpha values per line. 
    y_scaled = scaleYData(sortedYData);
    y_scaled = [y_scaled(:) zeros(size(y_scaled(:)))]';

    faces = zeros(size(ind,1)*numLines, 3);

    % The faces are determined by the indices, a Nx3 matrix containing
    % consecutive integers. For instance, the first row is 2, 3, 4, the
    % next is 3, 4, 5, etc. For multiple lines, shift the indices by a
    % certain amount to get the proper triangulation.
    for i=1:numLines
        startIdx = 1 + size(ind,1) * (i - 1);
        endIdx = size(ind,1) * i;
        faces(startIdx:endIdx,:) = ind + ind(end) * (i - 1);
    end

    % For the vertices, the x-coordinates are a repeated vector of XData
    % dependent on the number of lines. The y-coordinates are a vector
    % containing alternating values between YData and 0. Together, this
    % begins the patch at the leftmost point of the first line (x1,y1),
    % then to (x1,0), then to (x2,x2), etc. It repeats for each line.
    vertices = [repmat(x(:), numLines, 1) y(:)];
    obj.PatchObject.Vertices = vertices;
    obj.PatchObject.Faces = faces;

    % Alpha values are based on the y-coordinates and are scaled from 1 to
    % the maximum y-coordinate.
    obj.PatchObject.FaceVertexAlphaData = y_scaled(:);

    c = getColors(numLines, obj.ColorOrder);
    if n >= 1
        c = repelem(c, (n-1) * 2, 1);
    end
    
    obj.PatchObject.FaceVertexCData = c;
end

function val = scaleYData(y)
    col_max = max(y, [], 1); % Finds the maximum y-value per line
    M = max(col_max, [], 'all'); % Finds the maximum y-value across all lines
    val = y + (M - col_max); % Scales up each line by the difference
end

function colors = getColors(numLines, colors)
    idx = mod((1:numLines)-1, size(colors,1)) + 1;
    colors = colors(idx,:);
end

function sortedY = sortLines(y)
    ncols = size(y, 2);
    [~, I] = max(y, [], 2);
    [~, sortedI] = sort(sum(I == 1:ncols), 'descend');
    sortedY = y(:,sortedI);
end
