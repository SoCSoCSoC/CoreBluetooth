//
//  ViewController.m
//  BLE
//
//  Created by lanou3g on 16/4/22.
//  Copyright © 2016年 QQ. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface ViewController ()<CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *cManager;
@property (nonatomic, strong) CBPeripheral *peripheral;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 创建中心控制器
    [self getCManager];
    
}

// 懒加载创建中心控制器
- (CBCentralManager *)getCManager{
    if (!_cManager) {
        // 设置代理为当前控制器,Peripheral Manager将Run在主线程中。如果你想用不同的线程做更加复杂的事情，你需创建一个队列（queue）并将它放在这儿
        _cManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:nil];
    }
    return _cManager;
}


// 更新状态 (中央管理器的状态已经改变了的时候调用)
// 该方法用于告诉Central Manager，要开始寻找一个指定的服务了。只要中心管理者初始化,就会触发此代理方法   不能在state非ON的情况下对我们的中心管理者进行操作
- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    
    /*
     CBCentralManagerStateUnknown = 0,
     CBCentralManagerStateResetting,
     CBCentralManagerStateUnsupported,
     CBCentralManagerStateUnauthorized,
     CBCentralManagerStatePoweredOff,
     CBCentralManagerStatePoweredOn,
     */
    switch (central.state) {
        case CBCentralManagerStateUnknown:
            NSLog(@"中心管理器状态未知");
            break;
        case CBCentralManagerStateResetting:
            NSLog(@"中心管理器状态重置");
            break;
        case CBCentralManagerStateUnsupported:
            NSLog(@"中心管理器状态不被支持");
            break;
        case CBCentralManagerStateUnauthorized:
            NSLog(@"中心管理器状态未被授权");
            break;
        case CBCentralManagerStatePoweredOff:
            NSLog(@"中心管理器状态电源关闭");
            break;
        case CBCentralManagerStatePoweredOn:
        {
            NSLog(@"中心管理器状态电源开启");
            // 在中心管理者成功开启后 开始搜索外设
            
            [self.cManager scanForPeripheralsWithServices:nil // 通过某些服务筛选外设
                                              options:nil]; // dict,条件
            // 搜索成功之后,会调用我们找到外设的代理方法 sercices为空则会扫描所有的设备
            // - (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI; //找到外设
            
        }
            break;
            
        default:
            break;
    }
 
    
}

/*!
 *  @param central              中央管理器提供此更新
 *  @param peripheral           一个外设对象
 *  @param advertisementData    一个包含任何广播和扫描响应数据的字典。
 *  @param RSSI                 RSSI（Received Signal Strength Indicator）是接收信号的强度指示
 *
 */
// 如果找到了设备,则代理会调用该方法,过滤外设
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    
    if ([peripheral.name hasPrefix:@"OBand"] && (ABS(RSSI.integerValue) > 35)) {
        // 在此处对我们的 advertisementData(外设携带的广播数据) 进行一些处理
        
        // 通常通过过滤,我们会得到一些外设,然后将外设储存到我们的可变数组中,
        // 这里由于附近只有1个设备, 所以我们先按1个外设进行处理
        // 标记我们的外设,让他的生命周期 = vc
        self.peripheral = peripheral;
        // 发现完之后就是进行连接
        [self.cManager connectPeripheral:self.peripheral options:nil];
    }

}

// 中心管理者连接外设成功,连接成功之后,可以进行服务和特征的发现
- (void)centralManager:(CBCentralManager *)central // 中心管理者
  didConnectPeripheral:(CBPeripheral *)peripheral // 外设
{
    NSLog(@"%@连接成功",peripheral.name);
    // 获取外设的服务们
    // 设置外设的代理
    self.peripheral.delegate = self;
    
    // 外设发现服务,传nil代表不过滤
    // 这里会触发外设的代理方法 - (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
    [self.peripheral discoverServices:nil];
}


// 外设连接失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%@连接失败",peripheral.name);
}

// 丢失连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%@断开连接",peripheral.name);
}

#pragma mark - 外设代理
// 发现外设的服务后调用的方法,下面的方法中凡是有error的在实际开发中,都要进行判断
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    // 判断没有失败
    if (error) {
        NSLog(@"error:%@",error.localizedDescription);
        return;
    }
    for (CBService *service in peripheral.services) {
        // 发现服务后,让设备再发现服务内部的特征们 didDiscoverCharacteristicsForService
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

// 发现外设服务里的特征的时候调用的代理方法
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{

    // 遍历特征
    for (CBCharacteristic *characteristic in service.characteristics) {
        // 获取特征对应的描述 didUpdateValueForDescriptor
        [peripheral discoverDescriptorsForCharacteristic:characteristic];
        // 获取特征的值 didUpdateValueForCharacteristic
        [peripheral readValueForCharacteristic:characteristic];

    }
}

// 更新特征的描述的值的时候会调用
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
    // 这里当描述的值更新的时候,直接调用此方法即可
    [peripheral readValueForDescriptor:descriptor];
}

// 更新特征的value的时候会调用
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    for (CBDescriptor *descriptor in characteristic.descriptors) {
        // 它会触发
        [peripheral readValueForDescriptor:descriptor];
    }
}

// 发现外设的特征的描述数组
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    // 在此处读取描述即可
    for (CBDescriptor *descriptor in characteristic.descriptors) {
        // 它会触发
        [peripheral readValueForDescriptor:descriptor];
    }
}

#pragma mark - 自定义方法
// 一般第三方框架or自定义的方法,可以加前缀与系统自带的方法加以区分.最好还设置一个宏来取消前缀

// 5.外设写数据到特征中

// 需要注意的是特征的属性是否支持写数据
- (void)peripheral:(CBPeripheral *)peripheral didWriteData:(NSData *)data forCharacteristic:(nonnull CBCharacteristic *)characteristic
{
    /*
     typedef NS_OPTIONS(NSUInteger, CBCharacteristicProperties) {
     CBCharacteristicPropertyBroadcast												= 0x01,
     CBCharacteristicPropertyRead													= 0x02,
     CBCharacteristicPropertyWriteWithoutResponse									= 0x04,
     CBCharacteristicPropertyWrite													= 0x08,
     CBCharacteristicPropertyNotify													= 0x10,
     CBCharacteristicPropertyIndicate												= 0x20,
     CBCharacteristicPropertyAuthenticatedSignedWrites								= 0x40,
     CBCharacteristicPropertyExtendedProperties										= 0x80,
     CBCharacteristicPropertyNotifyEncryptionRequired NS_ENUM_AVAILABLE(NA, 6_0)		= 0x100,
     CBCharacteristicPropertyIndicateEncryptionRequired NS_ENUM_AVAILABLE(NA, 6_0)	= 0x200
     };
     
     打印出特征的权限(characteristic.properties),可以看到有很多种,这是一个NS_OPTIONS的枚举,可以是多个值
     常见的又read,write,noitfy,indicate.知道这几个基本够用了,前俩是读写权限,后俩都是通知,俩不同的通知方式
     */
    NSLog(@"char.pro = %ld",characteristic.properties);
    // 此时由于枚举属性是NS_OPTIONS,所以一个枚举可能对应多个类型,所以判断不能用 = ,而应该用包含&
    if (characteristic.properties & CBCharacteristicPropertyWrite) {
        // 核心代码在这里
        [peripheral writeValue:data // 写入的数据
             forCharacteristic:characteristic // 写给哪个特征
                          type:CBCharacteristicWriteWithResponse];// 通过此响应记录是否成功写入
    }
}

// 6.通知的订阅和取消订阅
// 实际核心代码是一个方法
// 一般这两个方法要根据产品需求来确定写在何处
- (void)peripheral:(CBPeripheral *)peripheral regNotifyWithCharacteristic:(nonnull CBCharacteristic *)characteristic
{
    // 外设为特征订阅通知 数据会进入 peripheral:didUpdateValueForCharacteristic:error:方法
    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
}
- (void)peripheral:(CBPeripheral *)peripheral CancleRegNotifyWithCharacteristic:(nonnull CBCharacteristic *)characteristic
{
    // 外设取消订阅通知 数据会进入 peripheral:didUpdateValueForCharacteristic:error:方法
    [peripheral setNotifyValue:NO forCharacteristic:characteristic];
}

// 7.断开连接
- (void)dismissConentedWithPeripheral:(CBPeripheral *)peripheral
{
    // 停止扫描
    [self.cManager stopScan];
    // 断开连接
    [self.cManager cancelPeripheralConnection:peripheral];
}


@end
