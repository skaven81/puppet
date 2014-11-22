class setup_skaven (
    $uid            = 1000,
    $gid            = 1000,
    $addl_groups    = [ 'users' ],
){
    
    user { 'skaven':
        ensure  => 'present',
        uid     => $uid,
        gid     => $gid,
    }
}
