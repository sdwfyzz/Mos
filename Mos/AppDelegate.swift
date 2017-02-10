//
//  AppDelegate.swift
//  Mos
//
//  Created by Cb on 2017/1/10.
//  Copyright © 2017年 Cb. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // eventTap相关
    var eventTap:CFMachPort?
    let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
    let eventCallBack: CGEventTapCallBack = {
        (proxy, type, event, refcon) in
        
            // 是否返回原始事件
            var handbackOriginalEvent = true
        
            // 判断输入源
            if ScrollCore.isTouchPad(of: event) {
                // 当触控板输入, 啥都不干
            } else {
                // 当鼠标输入, 根据需要执行翻转方向/平滑滚动
                
                // 获取光标当前窗口信息, 用于在某些窗口中禁用
                // 更新每次的PID
                ScrollCore.lastEventTargetPID = ScrollCore.eventTargetPID
                ScrollCore.eventTargetPID = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
                // 如果目标PID有变化, 则重新获取一次窗口名字, 更新到 ScrollCore.eventTargetName 里面
                if ScrollCore.lastEventTargetPID != ScrollCore.eventTargetPID {
                    if let applicationBundleId = ScrollCore.getApplicationBundleIdFrom(pid: ScrollCore.eventTargetPID) {
                        ScrollCore.eventTargetBundleId = applicationBundleId
                    }
                }
                
                // 处理滚动数据
                var scrollY = Int64(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
                var scrollPtY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
                var scrollFixY = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
                // Y轴
                if scrollPtY != 0 || scrollFixY != 0 || scrollY != 0 {
                    // 是否翻转鼠标事件, 且窗口BundleId不在禁止翻转滚动列表内
                    if ScrollCore.option.reverse && !ScrollCore.applicationInReverseIgnoreList(bundleId: ScrollCore.eventTargetBundleId) {
                        scrollY = -scrollY
                        scrollPtY = -scrollPtY
                        scrollFixY = -scrollFixY
                        if !ScrollCore.option.smooth {
                            // 如果翻转了鼠标事件且不使用平滑滚动, 则需要重设一下原始的Y数据
                            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: scrollY)
                            event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: scrollPtY)
                            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: scrollFixY)
                        }
                    }
                    // 是否平滑滚动, 且窗口BundleId不包含在禁止翻转滚动列表内
                    if ScrollCore.option.smooth && !ScrollCore.applicationInSmoothIgnoreList(bundleId: ScrollCore.eventTargetBundleId) {
                        // 禁止返回原始事件
                        handbackOriginalEvent = false
                        // 如果输入值小于10, 则格式化为10
                        let absY = abs(scrollPtY)
                        if absY > 0.0 && absY < 10.0 {
                            ScrollCore.updateScrollData(Y: scrollPtY<0.0 ? -10.0 : 10.0, X: 0.0)
                        } else {
                            ScrollCore.updateScrollData(Y: scrollPtY, X: 0.0)
                        }
                        // 启动一下事件
                        ScrollCore.activeScrollEventPoster()
                    }
                }
                // X轴 (横向滚轮, 如 Logetech MxMaster)
                // if event.getIntegerValueField(.scrollWheelEventDeltaAxis2) != 0 {
                    // 暂时啥都不干
                // }
            }
        
            // 返回事件对象
            if handbackOriginalEvent {
                return Unmanaged.passRetained(event)
            } else {
                return nil
            }
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // 禁止重复运行
        let bundleID = Bundle.main.bundleIdentifier!
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil)
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 读取用户保存设置
        ScrollCore.readPreferencesData()
        // 开始截取事件
        eventTap = ScrollCore.startCapture(event: mask, to: eventCallBack, at: .cghidEventTap, where: .tailAppendEventTap, for: .defaultTap)
        // 初始化事件发送器
        ScrollCore.initScrollEventPoster()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // 停止截取事件
        ScrollCore.stopCapture(tap: eventTap)
        // 停止事件发送器
        ScrollCore.stopScrollEventPoster()
    }
}
