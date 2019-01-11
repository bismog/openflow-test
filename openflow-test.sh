#!/usr/bin/env bash

## This script came from http://910216.com/archives/ovs_flow.html
## https://www.evernote.com/l/ADAKTvs-PExBAbumw5TPovFAGWfgqCDmVI8

# Remove legacy resources
ip netns delete ns1
ip netns delete ns2
ip netns delete ns3
ip netns delete ns4

ovs-vsctl del-br vswitch0


# 创建namespace
ip netns add ns1
ip netns add ns2
ip netns add ns3
ip netns add ns4

# 创建tap设备
ip link add tap0 type veth peer name tap0_br
ip link add tap1 type veth peer name tap1_br
ip link add tap2 type veth peer name tap2_br
ip link add tap3 type veth peer name tap3_br
ip link add tap4 type veth peer name tap4_br
ip link add tap5 type veth peer name tap5_br
ip link add tap6 type veth peer name tap6_br
ip link add tap7 type veth peer name tap7_br

# 设置tap设备的namespace
ip link set tap0 netns ns1
ip link set tap1 netns ns1
ip link set tap2 netns ns2
ip link set tap3 netns ns2
ip link set tap4 netns ns3
ip link set tap5 netns ns3
ip link set tap6 netns ns4
ip link set tap7 netns ns4

# 创建OVS网桥
ovs-vsctl add-br vswitch0

# 将tap设备另一端绑到网桥
ovs-vsctl add-port vswitch0 tap0_br
ovs-vsctl add-port vswitch0 tap1_br
ovs-vsctl add-port vswitch0 tap2_br
ovs-vsctl add-port vswitch0 tap3_br
ovs-vsctl add-port vswitch0 tap4_br
ovs-vsctl add-port vswitch0 tap5_br
ovs-vsctl add-port vswitch0 tap6_br
ovs-vsctl add-port vswitch0 tap7_br


#+++++++++++++++++++++++++++++++#
# Section 1: Single table with flow rules priority
#+++++++++++++++++++++++++++++++#

# 启动tap0和tap3及它们的对端
ip netns exec ns1 ip link set tap0 up
ip netns exec ns2 ip link set tap3 up
ip link set tap0_br up
ip link set tap3_br up

# 设置tap0和tap3的ip地址
ip netns exec ns1 ip addr add 192.168.1.100 dev tap0
ip netns exec ns2 ip addr add 192.168.1.200 dev tap3

# 配置路由
ip netns exec ns1 route add -net 192.168.1.0 netmask 255.255.255.0 dev tap0
ip netns exec ns2 route add -net 192.168.1.0 netmask 255.255.255.0 dev tap3

read -p 'Try to ping between ns1 and ns2...'

# 测试网络连通性
ip netns exec ns1 ping 192.168.1.200

ovs-vsctl list interface tap0_br | grep "ofport "
ovs-vsctl list interface tap3_br | grep "ofport "

ovs-ofctl dump-flows vswitch0

ovs-ofctl del-flows vswitch0
ovs-ofctl dump-flows vswitch0

ip netns exec ns1 ping 192.168.1.200


#+++++++++++++++++++++++++++++++#
# Section 2: Multiple tables
#+++++++++++++++++++++++++++++++#

## Remove all flows
ovs-ofctl del-flows vswitch0


## Add flow rules in table1
vs-ofctl add-flow vswitch0 "table=1,priority=1,in_port=1,actions=output:4"
ovs-ofctl add-flow vswitch0 "table=1,priority=2,in_port=4,actions=output:1"
ovs-ofctl dump-flows vswitch0

read -p "Try to ping but failed?"
## ip netns exec ns1 ping 192.168.1.200

## Add a flow(transfer from table0 to table1)
ovs-ofctl add-flow vswitch0 "table=0,actions=goto_table=1"

## Try again
## ip netns exec ns1 ping 192.168..200


#+++++++++++++++++++++++++++++++#
# Section 3: Group table
#+++++++++++++++++++++++++++++++#

## Remove all flows
ovs-ofctl del-flows vswitch0
ovs-ofctl dump-flows vswitch0

ovs-ofctl -P OpenFlow13 dump-groups vswitch0

## Setup a rule transfer packet to table1
ovs-ofctl -O OpenFlow13 add-group vswitch0 "group_id=1,type=select,bucket=resubmit(,1)"
ovs-ofctl -O OpenFlow13 dump-groups vswitch0

## Add two flow rules to transfer packet to group table
ovs-ofctl -O OpenFlow13 add-flow vswitch0 "table=0,in_port=1,actions=group:1"
ovs-ofctl -O OpenFlow13 add-flow vswitch0 "table=0,in_port=4,actions=group:1"


## Add two flow rules to send packet to seperated output ports
ovs-ofctl add-flow vswitch0 "table=1,priority=1,in_port=1,actions=output:4"
ovs-ofctl add-flow vswitch0 "table=1,priority=2,in_port=4,actions=output:1"

## Try pinging
read -p "Try to ping with success..."

## ip netns exec ns1 ping 192.168..200





