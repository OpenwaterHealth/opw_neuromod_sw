function s = parse_xml(filename)
    % PARSE_XML Recursively parse xml
    %
    % USAGE:
    %   theStruct = parse_xml(filename)
    %
    % This function reads an xml file using XMLREAD, and then tries to
    % simplify the structure where it can. Because XMLREAD is covering a
    % wide range of possible structures, you wind up with many nodes who
    % have for example, a single child node, containing only a name and a
    % value. For these nodes, we simply make a field for the node, whose
    % value is the value of the child node. If the parsing fails, it
    % reverts to the original structuring.
    %   Original: obj
    %               .name = "Name"
    %               .attributes = [
    %                    attr1
    %                       .name = "Index"
    %                       .attributes = {}
    %                       .value = 0
    %                       .children = {}
    %                    attr1
    %                       .name = "Data"
    %                       .attributes = {}
    %                       .value = [1,2,3]
    %                       .children = {}
    %               .value = []
    %               .children = []
    %   After Parsing: obj
    %                   .name = "Name"
    %                   .Index = 0
    %                   .Data = [1,2,3]
    %           
    %
    % INPUTS:
    %   filename: file to read
    %
    % OUTPUTS:
    %   s: parsed structure
    %
    % See also XMLREAD
    
    % Version History
    % Created 2022-06-03
% PARSEXML Convert XML file to a MATLAB structure.
try
   tree = xmlread(filename);
catch
   error('Failed to read XML file %s.',filename);
end

% Recurse over child nodes. This could run into problems 
% with very deeply nested trees.
s = parseChildNodes(tree);

% ----- Local function PARSECHILDNODES -----
function children = parseChildNodes(theNode)
% Recurse over node children.
%children = [];
if theNode.hasChildNodes
   childNodes = theNode.getChildNodes;
   numChildNodes = childNodes.getLength;
   %allocCell = cell(1, 1);
   %children = struct(             ...
   %   'Name', allocCell, 'Attributes', allocCell,    ...
   %   'Data', allocCell, 'Children', allocCell);


    ii = 1;
    for count = 1:numChildNodes
        theChild = childNodes.item(count-1);
        nodeStruct = makeStructFromNode(theChild);
        if ~isempty(nodeStruct)
            try
                children(ii) = nodeStruct;
                ii = ii+1;
            catch
                try
                    children.(nodeStruct.Name) = nodeStruct.Data;
                catch
                    fn = fieldnames(nodeStruct);
                    if length(fn) == 1
                        try
                            children.(fn{1}) = nodeStruct.(fn{1});
                        catch
                            error('bad assignment')
                        end
                    end
                end
            end
            
        end
    end
else
    children = [];
end

% ----- Local function MAKESTRUCTFROMNODE -----
function nodeStruct = makeStructFromNode(theNode)
% Create structure of node info.

nodeStruct = struct(                        ...
   'Name', char(theNode.getNodeName),       ...
   'Attributes', parseAttributes(theNode),  ...
   'Data', '',                              ...
   'Children', parseChildNodes(theNode));

if any(strcmp(methods(theNode), 'getData'))
   nodeStruct.Data = char(theNode.getData); 
else
   nodeStruct.Data = '';
end

if strcmp(nodeStruct.Name, '#text') && isempty(strip(nodeStruct.Data))
  nodeStruct = [];
  return
elseif isvarname(nodeStruct.Name) && isempty(nodeStruct.Attributes) && isempty(nodeStruct.Data) && ~isempty(nodeStruct.Children)
    directStruct = struct();
    if isfield(nodeStruct.Children, 'Name')... % && strcmp(nodeStruct.Children.Name, '#text') ...
            && isfield(nodeStruct.Children, 'Attributes') && isempty(nodeStruct.Children.Attributes) ...
            && isfield(nodeStruct.Children, 'Data') ... % && ~isempty(nodeStruct.Children.Data) ...
            && isfield(nodeStruct.Children, 'Children') && isempty(nodeStruct.Children.Children)
        directStruct.(nodeStruct.Name) = strip(nodeStruct.Children.Data);
    else
        directStruct.(nodeStruct.Name) = nodeStruct.Children;
    end
    nodeStruct = directStruct;
end

% ----- Local function PARSEATTRIBUTES -----
function attributes = parseAttributes(theNode)
% Create attributes structure.

attributes = [];
if theNode.hasAttributes
   theAttributes = theNode.getAttributes;
   numAttributes = theAttributes.getLength;
   allocCell = cell(1, numAttributes);
   attributes = struct('Name', allocCell, 'Value', ...
                       allocCell);

   ii = 1;
   for count = 1:numAttributes
      attrib = theAttributes.item(count-1);

      if ~(strcmp(char(attrib.getName), '#text') && isempty(strip(char(attrib.getValue))))
        attributes(ii).Name = char(attrib.getName);
        attributes(ii).Value = strip(char(attrib.getValue));
        ii = ii+1;
      end
   end
end