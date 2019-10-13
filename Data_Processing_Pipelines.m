%% Hands-on Tutorial for Data Processing Pipelines
%
% American Society for Neurorehabilitation workshop on Reliability and
% Reproducibility in Neurorehabilitation Research. 
% 
% by James Finley, Ph.D. 10/16/19
%
% Although this tutorial focuses on data analysis, many problems with rigor
% and reproducibility arise before any data are collected (e.g. study
% design and sampling). There are several helpful resources on design of
% studies in the movement sciences. See _Foundations_ _of_ _Clinical_
% _Research_ by Portney and Watkins for a thorough overview of research
% methods for clinical applications.
%
%% Example #1: Using simulated data to develop and validate an analysis pipeline
%
% * *Take-home message #1*: Generating simulated data can help you build
% intuition about factors that may influence the variance in your
% measurements and reduce your statistical power. Thinking about these
% factors _before_ you collect your data can help you improve the rigor of
% your study design. 
%
% *Step 1: Conduct a virtual experiment and save the data* 
% 
% Here, we will simulate data from a study of split-belt treadmill
% adaptation. Changes in performence during motor adaptation tasks are
% often modeled using a double-exponential function that can capture early,
% rapid changes in performance, as well as more gradual changes that impact
% performance during the latter portions of adaptation.
% 
% We will use this knowledge to generate artifial data from a
% double-exponential function that has the following form. 
%
% $$SLA = A_f*e^{-B_f*n} + B_f*e^{-B_s*n}$$
%
% We simulate intersubject variability by randomly selecing coefficients
% (A_f and A_s) and rate terms (B_s and B_f) from normal distributions
% centered at values taken from the literature. We will also simulate noisy
% measurements and stride-to-stride variability by adding noise to the
% simulated step length asymmetry values. Lastly, since typical adaptation
% studies use a fixed _duration_ of adaptation, each participant may take a
% different number of total strides (largely because of differences in leg
% length). We simulate this source of variability by having each
% participant take between 800 and 1100 total strides.

% Set the random number generator to the default state so that the results
% are reproducible.
rng('default')      

% Define the number of virtual participants
N_Participants = 16;

% Make a new folder in the current directory to store the data
mkdir ASNR_Matlab_Data
Home = cd;  % Remember the current directory so that we can return to it

% Allocate space to save the true parameter values.
True_Parameters = zeros(16,4);

% Create a figure to show all of the simulated data
figure

for i = 1:N_Participants
    cd('ASNR_Matlab_Data')
    
    % Create subdirectory for each participant. Note that the
    % sub-directories have a consistent naming convention with a two-digit
    % subject ID. If you were to simulate more than 99 participants, you
    % would want to modify the form of the participant ID numbers to
    % accomodate the largest number of participants you expect. 
    
    if i < 10
        mkdir(strcat(['20191016_S0' num2str(i)]))
        cd(strcat(['20191016_S0' num2str(i)]))
    else
        mkdir(strcat(['20191016_S' num2str(i)]))
        cd(strcat(['20191016_S' num2str(i)]))
    end
    
    % Specify the number of strides for each participant as a random value
    % between 800 and 1100.
    Total_Strides = randi([800 1100],1,1);    
    
    % Create a "time" vector with units of strides
    Stride_Num = 1:Total_Strides;
    
    % Specify the fast and slow coefficients. The sum of A_Fast and A_Slow
    % are approximately equal to the initial step length asymmetry. 
    %
    % Note that each coefficient has a nominal value of -0.05 and we
    % introduce between-subjects variability by taking a random value
    % between -0.5 and 0.5 and multiplying that number by 0.1. In other
    % words, these coefficients range from -0.1 to 0. 
    
    A_Fast = -0.05+0.1*(rand(1,1)-0.5); 
    A_Slow = -0.05+0.1*(rand(1,1)-0.5); 
    
    % B_Fast and B_Slow are the time constants of the fast and slow
    % components of adaptation. The fast time constant should be larger
    % than the slow time constant. Again, we add some random deviation to
    % these parameters to introduce between-subjects variance. The nominal
    % values for these parameters were taken from Mawase et al., 2013,
    % Journal of Neurophysiology.
    
    B_Fast = 0.025+0.01*(rand(1,1)-0.5); 
    B_Slow = 0.0011+0.0004*(randn(1,1)-0.5);
    
    % Store the true values of the parameters for each participant. We will
    % use this as our ground truth at the end of the demo to determine if
    % we can accurately estimate these parameters from the data.
    True_Parameters(i,:) = [A_Slow B_Slow A_Fast B_Fast];
    
    % Assume that each participant has normally distributed measurement
    % noise, and that the amplitude of this noise varies uniformly across
    % participants. The values used for noise amplitude were hand picked to
    % generate data sets that look fairly realistic. 
    
    Noise_Amplitude = 0.02*rand(1,1)+0.005;
    Measurement_Noise = Noise_Amplitude*randn(1,numel(Stride_Num));
    
    % Generate step length asymmetries (SLA) for each participant by adding
    % measurement noise to the step length asymmetries that would be
    % generated by the double exponential model.
    SLA = A_Fast*exp(-B_Fast*Stride_Num) + ...
        A_Slow*exp(-B_Slow*Stride_Num) +...
        Measurement_Noise;
    
    % Plot the raw step length asymmetry data for all participants
    ax(i) = subplot(4,4,i); plot(SLA,'o');
    xlabel('Stride Number'), ylabel('Step Len. Asym')
    
    % Save the data in a csv file
    if i < 10
        csvwrite(strcat(['20191016_S0' num2str(i) '_SLA.csv']),SLA)
    else
        csvwrite(strcat(['20191016_S' num2str(i) '_SLA.csv']),SLA)
    end
    cd(Home)
end
linkaxes(ax)

%% Load the data for all participants into a single data structure and perform visual quality control
%
% By storing the data for all participants in a single, well-organized
% data structure, you can easily share your data with other Matlab users in
% a self-explanatory format. 
 
cd('ASNR_Matlab_Data')
Directory = dir;

% Create a new figure window to perform high-level quality control
figure
for i = 1:N_Participants
    % Use the csvread function to import the step length asymmetry data
    % from the .csv files into Matlab
    % 
    % Note that we are storing the data within a structure. See the Matlab
    % help for structures if you are not familiar with this data type.
    
    Data(i).SLA = csvread(strcat([Directory(i+2).name '\' ...
        Directory(i+2).name '_SLA.csv'])); 
    
    % Visualize the data and determine if the data for each participant
    % seems reasonable. This manual sanity could be made more quantitative,
    % but our purpose is to demostrate how you can automate _some_
    % quality control processes.
    
    plot(Data(i).SLA,'o'), xlabel('Stride Number'), ylabel('SLA')
    Data(i).Good_Data = questdlg('Does This Data Seem Reasonable?');
    
    % Add some artificial demographic information to illustrate the
    % versatility of data structures.
    
    Data(i).Age = randi([20 48],1,1);
    Data(i).Weight = randi([50 90],1,1);
end

% Save the data structure
save Data_All Data True_Parameters

%% Compute summary measures and store results in a table

% Load the group data
load Data_All

% Here, we use nonlinear regression to estimate the coefficients and rate
% parameters for each participant. We will then compare these estimates to
% the true values to validate our analysis procedure.

% Define the model's structure. See the help for 'fitnlm' for a more
% descriptive example of how model structure is defined for the 'fitnlm'
% function.
Double_Exp_Model = @(Coeff,x)Coeff(1)*exp(-Coeff(2)*x(:,1))+Coeff(3)*exp(-Coeff(4)*x(:,1));

% Specify initial guess for model parameters. These initial guess are
% purposefully set to be equal to the nominal values defined above.
% However, you should vary these values to see if the fitting procedure is
% sensitive to the initial guess. 
Coeff_Init = [-0.05 0.025 -0.05 0.011]';

% We will store the parameter estimates in a table. Tables are relatively
% recent addition to Matlab and they allow you to store different data
% types in a spreadsheet format as you might do in Excel. Here, we are
% simply creating a table with the correct column names.
Coefficients_All = array2table(zeros(1,4),'VariableNames',{'A_Slow' 'B_Slow' 'A_Fast' 'B_Fast'});

% In this block of code, we estimate the dual-rate model parameters using
% the _fitnlm_ function. Note that we include a conditional statement so
% that we only fit data that passed our earlier screening.

for i = 1:numel(Directory)-2
    if strcmp(Data(i).Good_Data,'Yes')
        % Use the 'fitnlm' function to estimate the model parameters
        Data(i).Model = fitnlm((1:numel(Data(i).SLA))',Data(i).SLA',...
            Double_Exp_Model,Coeff_Init);
        % Make sure that the parameters are stored in the proper order
        if Data(i).Model.Coefficients.Estimate(2) > Data(i).Model.Coefficients.Estimate(4)
            Coefficients_All(i,:) = array2table(Data(i).Model.Coefficients.Estimate([3 4 1 2])');
        else
            Coefficients_All(i,:) = array2table(Data(i).Model.Coefficients.Estimate');
        end
    else
        % Store NaN values for data that did not pass our screening
        Coefficients_All(i,:) = array2table(NaN(1,4));
    end
end

save Group_Data Coefficients_All
%% Visualize summary data and save as a publication-quality figure

% We will create a single figure with four subplots. The left column will
% show the distribution of estimated and actual parameters for the slow
% process and the right column will show the distribution of estimated and
% actual parameters for the fast process.
%
% Note that we explicitly define many of the parameters of the plot
% including the axis limits and labels, line widths, and font sizes. We
% even add panel labels as you would do for a publication.
%
% Finally, we set the figure's size to 15 x 12 cm which is approximately two
% columns in a standard scientific publication. 

figure
Not_NaN = ~isnan(Coefficients_All.A_Slow);
A_Axes(1) = subplot(2,2,1); plot([Coefficients_All.A_Slow(Not_NaN)...
    True_Parameters(Not_NaN,1)]','-o','LineWidth',1,'Color',...
    [0.1 0.1 0.1],'MarkerFaceColor',[0.5 0.5 0.5])
set(gca,'XLim', [0.5 2.5], 'XTick',[1 2],'XTickLabel',...
    {'Estimated' 'True'},'FontSize',11,'LineWidth',1)
ylabel('Slow Coefficient')
XLimits = xlim; YLimits = ylim;
text(XLimits(1)-0.3*(XLimits(2)-XLimits(1)),YLimits(2)+0.1*(YLimits(2)-YLimits(1)),'A','FontSize',14)

A_Axes(2) = subplot(2,2,2); plot([Coefficients_All.A_Fast(Not_NaN)...
    True_Parameters(Not_NaN,3)]','-o','LineWidth',1,'Color',...
    [0.1 0.1 0.1],'MarkerFaceColor',[0.5 0.5 0.5])
set(gca,'XLim', [0.5 2.5], 'XTick',[1 2],'XTickLabel',...
    {'Estimated' 'True'},'FontSize',11,'LineWidth',1)
ylabel('Fast Coefficient')
XLimits = xlim; YLimits = ylim;
text(XLimits(1)-0.3*(XLimits(2)-XLimits(1)),YLimits(2)+0.1*(YLimits(2)-YLimits(1)),'B','FontSize',14)

linkaxes(A_Axes)

B_Axes(1) = subplot(2,2,3); plot([Coefficients_All.B_Slow(Not_NaN)...
    True_Parameters(Not_NaN,2)]','-o','LineWidth',1,'Color',...
    [0.1 0.1 0.1],'MarkerFaceColor',[0.5 0.5 0.5])
set(gca,'XLim', [0.5 2.5], 'XTick',[1 2],'XTickLabel',...
    {'Estimated' 'True'},'FontSize',11,'LineWidth',1)
ylabel('Slow Rate Constant')
XLimits = xlim; YLimits = ylim;
text(XLimits(1)-0.3*(XLimits(2)-XLimits(1)),YLimits(2)+0.1*(YLimits(2)-YLimits(1)),'C','FontSize',14)

B_Axes(2) = subplot(2,2,4); plot([Coefficients_All.B_Fast(Not_NaN)...
    True_Parameters(Not_NaN,4)]','-o','LineWidth',1,'Color',...
    [0.1 0.1 0.1],'MarkerFaceColor',[0.5 0.5 0.5])
set(gca,'XLim', [0.5 2.5], 'XTick',[1 2],'XTickLabel',...
    {'Estimated' 'True'},'FontSize',11,'LineWidth',1)
ylabel('Fast Rate Constant')
XLimits = xlim; YLimits = ylim;
text(XLimits(1)-0.3*(XLimits(2)-XLimits(1)),YLimits(2)+0.1*(YLimits(2)-YLimits(1)),'D','FontSize',14)

linkaxes(B_Axes)

% Perform a set of paired t-tests to determine if there is evidence to
% reject the null hypothesis that the mean of the differences between the
% estimated and actual model parameters is different from zero.
[h_A_Slow, p_A_Slow] = ttest(Coefficients_All.A_Slow(Not_NaN), True_Parameters(Not_NaN,1));
[h_A_Fast, p_A_Fast] = ttest(Coefficients_All.A_Fast(Not_NaN), True_Parameters(Not_NaN,3));
[h_B_Slow, p_B_Slow] = ttest(Coefficients_All.B_Slow(Not_NaN), True_Parameters(Not_NaN,2));
[h_B_Fast, p_B_Fast] = ttest(Coefficients_All.B_Fast(Not_NaN), True_Parameters(Not_NaN,4));

set(gcf,'Units','Centimeters','Position',[11 14 15 12])
saveas(gcf,'Coefficient Estimates - Group','pdf')
