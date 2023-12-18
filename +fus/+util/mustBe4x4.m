function mustBe4x4(matrix)
    if ~isequal(size(matrix), [4,4])
        error('mustBe4x4:Not4x4', 'Must be 4x4');
    end
end
