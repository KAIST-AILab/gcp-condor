import os
import time

import parse
from tqdm import tqdm

MIN_NUM_INSTANCES = 0
MAX_NUM_INSTANCES = 10
INSTANCE_GROUP_NAME = 'condor-compute-pvm-igm'
zone = os.popen('cd /; gcloud compute instances list --filter="name=condor-master" --format "csv[no-heading](zone)"').read().strip()

while True:
    print('=' * 80)
    print('CONFIG: min_size=%d / max_size=%d' % (MIN_NUM_INSTANCES, MAX_NUM_INSTANCES))
    min_replicas, max_replicas, target_size = os.popen('cd /; gcloud compute instance-groups managed describe %s --zone=%s --format="csv(autoscaler.autoscalingPolicy.minNumReplicas,autoscaler.autoscalingPolicy.maxNumReplicas,targetSize)"' % (INSTANCE_GROUP_NAME, zone)).read().strip().split('\n')[-1].split(",")
    min_replicas, max_replicas, target_size = int(min_replicas), int(max_replicas), int(target_size)
    print('GCLOUD: minNumReplicas=%d / maxNumReplicas=%d / targetSize=%d' % (min_replicas, max_replicas, target_size))

    lines = os.popen('condor_q').read().split('\n')
    for line in lines:
        # Total for all users: 88 jobs; 0 completed, 0 removed, 86 idle, 2 running, 0 held, 0 suspended
        if 'Total for all users:' in line:
            result = parse.parse('Total for all users: {} jobs; {} completed, {} removed, {} idle, {} running, {} held, {} suspended', line)
            jobs, completed, removed, idle, running, held, suspended = [int(x) for x in list(result)]
            print('CONDOR: jobs=%d / idle=%d / running=%d / held=%d' % (jobs, idle, running, held))

            my_target_size = max(min(idle + running + held, MAX_NUM_INSTANCES), MIN_NUM_INSTANCES)
            print('NEW: target_size=%d' % my_target_size)

            if my_target_size > target_size:
                print('Increase # instances: %d -> %d' % (target_size, my_target_size))
                print('=' * 80)
                os.system('cd /; gcloud compute instance-groups managed set-autoscaling %s --zone=%s --max-num-replicas=%d --min-num-replicas=%d' % (INSTANCE_GROUP_NAME, zone, my_target_size, my_target_size))
            elif my_target_size < target_size:
                print('Decrease # instances: %d -> %d' % (target_size, my_target_size))
                print('=' * 80)
                os.system('cd /; gcloud compute instance-groups managed set-autoscaling %s --zone=%s --max-num-replicas=%d --min-num-replicas=%d' % (INSTANCE_GROUP_NAME, zone, my_target_size, my_target_size))
            else:
                print('Good!')
                print('=' * 80)

    for i in tqdm(range(60), desc='sleep'):
        time.sleep(1)
