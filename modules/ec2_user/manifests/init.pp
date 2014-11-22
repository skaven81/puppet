class ec2_user (
    $uid            = 1000,
    $gid            = 1000,
    $addl_groups    = [ 'adm', 'wheel', 'systemd-journal' ],
){
    
    user { 'ec2-user':
        ensure  => 'present',
        uid     => $uid,
        gid     => $gid,
        groups  => $addl_groups,
    }

    group { 'ec2-user':
        ensure  => 'present',
        gid     => $gid,
    }
}
