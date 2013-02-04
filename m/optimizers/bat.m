function [xbest,fbest,exitflag,output]=bat(objective,x0,lb,ub,options,varargin)

% Reference: 
% Gaige Wang, Lihong Guo, Hong Duan, Luo Liu and Heqi Wang (2012): " A Bat
% Algorithm with Mutation for UCAV Path Planning". The Scientific World
% Journal, vol. 2012

default_options = optimization_universal_options();

specific_options=struct('loudness',.5,'pulse_rate',.5,...
    'variable_loudness',false,'min_frequency',0,'max_frequency',2,...
    'alpha',.9,'gamma',.9);

default_options=mergestructures(default_options,specific_options);

if nargin==0
    xbest=default_options;
    return
end

if nargin<5
    options=[];
end
ff=fieldnames(default_options);
for ifield=1:numel(ff)
    v=ff{ifield};
    if isfield(options,v)
        default_options.(v)=options.(v);
    end
end
n=default_options.MaxNodes;      % Population size, typically 10 to 40
A=default_options.loudness;      % Loudness  (constant or decreasing)
r=default_options.pulse_rate;      % Pulse rate (constant or decreasing)
% This frequency range determines the scalings
% You should change these values if necessary
Qmin=default_options.min_frequency;         % Frequency minimum
Qmax=default_options.max_frequency;         % Frequency maximum
nonlcon=default_options.nonlcon;
alpha=default_options.alpha;
gamma=default_options.gamma;
verbose=default_options.verbose;
variable_loudness=default_options.variable_loudness;

output={'MaxIter','MaxTime','MaxFunEvals','start_time'};
not_needed=fieldnames(rmfield(default_options,output));
output=rmfield(default_options,not_needed);
output.funcCount = 0;
output.iterations = 0;
output.algorithm = mfilename;
% Dimension of the search variables
npar=numel(lb);           % Number of dimensions

% Initialize the population/solutions
bat_pop=wrapper(x0);
for i=2:n
    x=lb+(ub-lb).*rand(npar,1);
    bat_pop(1,i)=wrapper(x);
end

bat_pop=sort_population(bat_pop,0);
% Find the initial best_bat solution
best_bat=bat_pop(1);

if ~default_options.stopping_created
    manual_stopping();
end
stopflag=check_convergence(output);
while isempty(stopflag)
    output.iterations=output.iterations+1;
    % Loop over all bats/solutions
    for i=1:n
        Qi=Qmin+(Qmin-Qmax)*rand;
        bat_pop(i).v=bat_pop(i).v+(bat_pop(i).x-best_bat.x)*Qi;
        popi=wrapper(bat_pop(i).x+bat_pop(i).v);
        % Pulse rate
        if rand>bat_pop(i).r
%             r4=max(1,ceil(n*rand)); % select one of the best_bat here. this should change
%             % The factor 0.001 limits the step sizes of random walks
%             Su=bat_pop(r4).x+0.001*randn(npar,1);
            Su=best_bat.x+0.001*randn(npar,1);
            popu=wrapper(Su);
            popi=selection_process(popu,popi);
        end
        % generate a new solution by flying randomly
        epsilon=2*rand-1;
        pop_rand=wrapper(bat_pop(i).x+epsilon*mean([bat_pop.A],2));
        popi=selection_process(pop_rand,popi);

        % Update if the solution improves, or not too loud
        choice=compare_individuals(popi,bat_pop(i));
%         if choice==1 && rand<bat_pop(i).A
        if choice==1 || rand<bat_pop(i).A
            bat_pop(i).x=popi.x;
            bat_pop(i).f=popi.f;
            if variable_loudness
                t=output.iterations;
                bat_pop(i).r=r*(1-exp(-gamma*t));
                bat_pop(i).A=alpha*bat_pop(i).A;
            end
        end
        % Update the current best_bat solution
        best_bat=selection_process(best_bat,popi);
    end
    if rem(output.iterations,verbose)==0 || output.iterations==1
        restart=1;
        fmin_iter=best_bat.f;
        disperse=dispersion([bat_pop.x],lb,ub);
        display_progress(restart,output.iterations,best_bat.f,fmin_iter,...
            disperse,output.funcCount,output.algorithm);
    end
    stopflag=check_convergence(output);
end

xbest=best_bat.x;
fbest=best_bat.f;
exitflag=1;

    function this=wrapper(x)
        if nargin==0
            this=evaluate_individual();
            this.v=[];   % Velocities
            this.r=[];   % pulse rate
            this.A=[];
        else
            this=evaluate_individual(x,objective,lb,ub,nonlcon,varargin{:});
            this.v=0;   % Velocities
            this.r=r;   % pulse rate
            this.A =A;  % loudness
            output.funcCount=output.funcCount+1;
        end
    end

end

