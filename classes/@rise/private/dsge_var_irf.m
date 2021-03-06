function irfs=dsge_var_irf(obj,params,steps,filter_flag,verbose,resolve_flag)
if nargin<6
    resolve_flag=[];
    if nargin<5
        verbose=false;
        if nargin<4
            filter_flag=false;
            if nargin<3
                steps=[];
                if nargin<2
                    params=[];
                end
            end
        end
    end
end
if isempty(resolve_flag)
    resolve_flag=true;
end
if isempty(steps)
    steps=obj.options.irf_periods;
end
% compute PHIb, SIGb and ZZi 
[DistrLocations,hyperparams]=distribution_locations_and_hyperparameters(obj);
[logpost,LogLik,~,obj]=dsge_var_posterior(params,obj,...
    DistrLocations,hyperparams,filter_flag,verbose,resolve_flag); %#ok<ASGLU>
T=obj.dsge_var.T;
n=obj.dsge_var.n;
p=obj.dsge_var.p;
constant=obj.dsge_var.constant;
lambda=obj.parameters(obj.dsge_prior_weight_id).startval;
S=(1+lambda)*T*obj.dsge_var.posterior.SIG;
df=obj.dsge_var.posterior.inverse_wishart.df;
SIG_draw=inverse_wishart_rand(S,df);

PHI=obj.dsge_var.posterior.PHI;
companion_form=[PHI(constant+1:end,:)'
    eye(n*(p-1)),zeros(n*(p-1),n)];
COV_PHI=kron(SIG_draw,obj.dsge_var.posterior.ZZi);
CS=transpose(chol(COV_PHI));
is_explosive=true;
while is_explosive
    PHI_draw=PHI(:)+CS*randn(size(CS,1),1);
    PHI_draw=reshape(PHI_draw,size(PHI));
    companion_form(1:n,:)=PHI_draw(constant+1:end,:)';
    is_explosive=max(eig(companion_form))>=obj.options.qz_criterium;
end

% compute the mean
if constant
    c=[PHI_draw(1,:)';zeros(n*(p-1),1)];
    mu=(eye(size(companion_form))-companion_form)\c;
    mu=mu(1:n); % keep only the relevant ones
    mu=repmat(mu',1,obj.NumberOfExogenous);
else
    mu=zeros(1,n*obj.NumberOfExogenous);
end
    
% Get rotation
Atheta = obj.R;
A0 = Atheta([obj.varobs.id],:);
[OMEGAstar,SIGMAtr] = qr(A0'); %#ok<NASGU>

% identification
SIGtrOMEGA = transpose(chol(SIG_draw))*OMEGAstar';
%%
irfs = zeros (steps+1,n*obj.NumberOfExogenous);
PHIpower = companion_form;
for t = 1:steps
    if t==1
        tmp3 = SIGtrOMEGA;
    else
        tmp3 = PHIpower(1:n,1:n)*SIGtrOMEGA;
    end
    irfs(t+1,:)  = tmp3(:);
    PHIpower = companion_form*PHIpower;
end
irfs=reshape(bsxfun(@plus,irfs,mu),[steps+1,n,obj.NumberOfExogenous]);
irfs=permute(irfs,[2,1,3]);

function SIG_draw=inverse_wishart_rand(S,df)
CS=transpose(chol(S\eye(df(2))));
SIG_draw=CS*randn(df)';
SIG_draw=SIG_draw*SIG_draw';
SIG_draw=SIG_draw\eye(df(2));
