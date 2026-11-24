# Helpers shared by test files, so each file runs alone as well as in the suite.

# Every ordering of 1:n (n >= 1), each as a vector.
function all_perms(n)
    n == 1 && return [[1]]
    [insert!(copy(q), j, n) for q in all_perms(n - 1) for j in 1:n]
end
