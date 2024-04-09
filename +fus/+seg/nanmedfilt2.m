function [M] = nanmedfilt2(A, sz)
%This MATLAB function performs median filtering of the matrix A in two dimensions
%while *ignoring* NaNs (based on discussions here
%http://www.mathworks.com/matlabcentral/newsreader/view_thread/251787)

%A is a 2d matrix, sz is tile size, M is filtered A.

if nargin<2
    sz = 5;
end
if length(sz)==1
    sz = [sz sz];
end

if any(mod(sz,2)==0)
    error('kernel size SZ must be odd)')
end
margin=(sz-1)/2;
AA = nan(size(A)+2*margin);
AA(1+margin(1):end-margin(1),1+margin(2):end-margin(2))=A;
[iB,jB]=ndgrid(1:sz(1),1:sz(2));
is=sub2ind(size(AA),iB,jB);
[iA, jA]=ndgrid(1:size(A,1),1:size(A,2));
iA=sub2ind(size(AA),iA,jA);
idx=bsxfun(@plus,iA(:).',is(:)-1);

B = sort(AA(idx),1);
j=any(isnan(B),1);
last = zeros(1,size(B,2))+size(B,1);
[~, last(j)]=max(isnan(B(:,j)),[],1);
last(j)=last(j)-1;

M = nan(1,size(B,2));
valid = find(last>0);
mid = (1 + last)/2;
i1 = floor(mid(valid));
i2 = ceil(mid(valid));
i1 = sub2ind(size(B),i1,valid);
i2 = sub2ind(size(B),i2,valid);
M(valid) = 0.5*(B(i1) + B(i2));
M = reshape(M,size(A));

end % medianna

