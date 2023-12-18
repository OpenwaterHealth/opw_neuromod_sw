function tasks = get_tasks()
    [~, taskstr] = system('tasklist');
    lines = splitlines(taskstr);
    dividers = split(lines{3},' ');
    colwidth = cellfun('length', dividers);
    headline = lines{2};
    headers = cell(1, length(dividers));
    for i = 1:length(dividers)
        headers{i} = strip(headline(sum(colwidth(1:i-1))+(i-1)+(1:colwidth(i))));
        headers{i} = strrep(strrep(headers{i}, ' ', '_'), '#', '');
    end
    
    data = lines(4:end-1);
    for j = 1:length(data)
        s = struct();
        for i = 1:length(dividers)
            s.(headers{i}) = strip(data{j}(sum(colwidth(1:i-1))+(i-1)+(1:colwidth(i))));
        end
        data_struct(j) = s;
    end 
    tasks = struct2table(data_struct);
end
