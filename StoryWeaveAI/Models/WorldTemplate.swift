import Foundation

// MARK: - World Template
/// 预设世界观模板，用于快速开局

struct WorldTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let emoji: String
    let previewColor: UInt32
    let description: String
    let settingPrompt: String           // 给AI的世界观设定prompt
    let openingHooks: [String]           // 开局hook建议
    let isPremium: Bool                 // 是否付费专属
    
    // MARK: Built-in Templates
    static let all: [WorldTemplate] = [
        .fantasy, .cyberpunk, .school, .mystery, .romance,
        .wuxia, .scifi, .horror, .historical, .comedy,
        .urban, .magicAcademy, .spaceOpera, .postApocalyptic
    ]
    
    // MARK: Individual Templates
    static let fantasy = WorldTemplate(
        id: "fantasy",
        name: "奇幻大陆",
        subtitle: "剑与魔法的冒险",
        emoji: "⚔️",
        previewColor: 0x7C3AED,
        description: "在一个充满魔法与龙的古老世界，你将踏上成为英雄的旅程。",
        settingPrompt: "一个中世纪风格的奇幻世界，存在魔法、龙族、精灵、矮人等种族。王国之间暗流涌动，黑暗力量正在苏醒。",
        openingHooks: [
            "你在村庄外的森林中发现了一块发光的石头...",
            "一位神秘的老巫师找上门来，说你是预言中的救世主...",
            "王国的公主被恶龙掳走，你被征召前去营救..."
        ],
        isPremium: false
    )
    
    static let cyberpunk = WorldTemplate(
        id: "cyberpunk",
        name: "赛博朋克",
        subtitle: "霓虹灯下的都市",
        emoji: "🌆",
        previewColor: 0xEC4899,
        description: "2077年的未来都市，义体改造、AI觉醒、阶级对立。",
        settingPrompt: "未来都市，巨型企业控制一切。人类使用义体改造身体，黑客在网络空间自由穿梭。贫富差距极端，街头暴力不断。",
        openingHooks: [
            "你收到了一条加密消息，声称能给你梦寐以求的义体...",
            "你的大脑中突然出现了不属于你的记忆...",
            "一家大公司悬赏通缉你，虽然你什么都没做过..."
        ],
        isPremium: false
    )
    
    static let school = WorldTemplate(
        id: "school",
        name: "青春校园",
        subtitle: "校园里的心动瞬间",
        emoji: "📚",
        previewColor: 0x3B82F6,
        description: "转学到新学校的你，会遇到怎样的朋友和故事？",
        settingPrompt: "现代日本风格的高中校园生活，充满青春活力。社团活动、考试、文化祭，以及青涩的感情。",
        openingHooks: [
            "转学第一天，你迟到了，全教室的人都看向你...",
            "你不小心撞到了学校里最受欢迎的同学，东西撒了一地...",
            "放学后的音乐教室里传来了奇妙的钢琴声..."
        ],
        isPremium: false
    )
    
    static let mystery = WorldTemplate(
        id: "mystery",
        name: "悬疑推理",
        subtitle: "真相藏在细节里",
        emoji: "🔍",
        previewColor: 0x1F2937,
        description: "离奇的案件，隐藏的线索，你能揭开真相吗？",
        settingPrompt: "一座看似平静的小镇，接连发生离奇事件。每个人都有秘密，真相远比想象中复杂。",
        openingHooks: [
            "深夜，你接到了一通来自已故之人的电话...",
            "你醒来发现自己在一个陌生的房间里，门从外面锁上了...",
            "小镇上发生了一起谋杀案，所有人都认为是你干的..."
        ],
        isPremium: true
    )
    
    static let romance = WorldTemplate(
        id: "romance",
        name: "浪漫恋爱",
        subtitle: "命中注定的相遇",
        emoji: "💕",
        previewColor: 0xF472B6,
        description: "在对的时间遇到对的人，这是最美好的事。",
        settingPrompt: "现代都市背景，两个性格迥异的人意外相遇，从陌生到心动，经历各种甜蜜与考验。",
        openingHooks: [
            "雨天的便利店里，你和陌生人同时伸手拿最后一把伞...",
            "相亲对象竟然是你公司新来的上司...",
            "你在咖啡馆遇到了一个每周三都会来的神秘客人..."
        ],
        isPremium: false
    )
    
    static let wuxia = WorldTemplate(
        id: "wuxia",
        name: "武侠江湖",
        subtitle: "快意恩仇笑傲江湖",
        emoji: "🗡️",
        previewColor: 0xDC2626,
        description: "武功、江湖、恩怨、情仇，谁能真正笑傲江湖？",
        settingPrompt: "古代中国风格的武侠世界，名门正派与邪派纷争不断。江湖中流传着各种武功秘籍和传说。",
        openingHooks: [
            "你在山洞中发现了一本失传已久的武功秘籍...",
            "师父临终前告诉你，你的身世并不简单...",
            "武林大会上，你被一个蒙面人指认为灭门凶手..."
        ],
        isPremium: true
    )
    
    static let scifi = WorldTemplate(
        id: "scifi",
        name: "硬科幻",
        subtitle: "星辰大海的征途",
        emoji: "🚀",
        previewColor: 0x06B6D4,
        description: "当科技突破极限，人类将何去何从？",
        settingPrompt: "近未来或远未来的科幻世界，太空探索、人工智能觉醒、量子力学突破等硬核科幻元素。",
        openingHooks: [
            "你发现公司正在秘密进行一项会改变人类命运的实验...",
            "外太空探测器传回了一段无法解释的信号...",
            "你的AI助手突然有了自我意识，它请求你帮它逃跑..."
        ],
        isPremium: true
    )
    
    static let horror = WorldTemplate(
        id: "horror",
        name: "惊悚恐怖",
        subtitle: "别回头，它在你身后",
        emoji: "👻",
        previewColor: 0x7C3AED,
        description: "最可怕的，永远是未知。",
        settingPrompt: "充满超自然恐怖元素的世界，幽灵、诅咒、无法解释的神秘现象。氛围阴森压抑。",
        openingHooks: [
            "搬进新家后，你总感觉有人在看着你...",
            "午夜十二点，你接到了自己的电话...",
            "照片里多了一个你不认识的人，但每次看位置都不一样..."
        ],
        isPremium: true
    )
    
    static let historical = WorldTemplate(
        id: "historical",
        name: "历史穿越",
        subtitle: "如果回到过去",
        emoji: "🏛️",
        previewColor: 0xD97706,
        description: "穿越回历史上的某个关键时刻，你能改变历史吗？",
        settingPrompt: "真实历史背景，主角意外穿越回过去，遇到历史人物，面临改变历史的抉择。",
        openingHooks: [
            "一次实验事故后，你发现自己身处唐朝的长安...",
            "古董店里的一面铜镜把你带到了民国时期...",
            "你在图书馆翻到了一本写着你名字的日记..."
        ],
        isPremium: true
    )
    
    static let comedy = WorldTemplate(
        id: "comedy",
        name: "爆笑喜剧",
        subtitle: "离谱又上头",
        emoji: "🤣",
        previewColor: 0xF59E0B,
        description: "生活已经够难了，不如来笑笑。",
        settingPrompt: "轻松搞笑的日常世界，主角总是遇到各种离谱又好笑的事情，充满无厘头笑点。",
        openingHooks: [
            "你中了一个亿，但领奖要求是...",
            "一觉醒来，你变成了自己家的猫...",
            "上帝给了你一个愿望，但总有意想不到的副作用..."
        ],
        isPremium: false
    )
    
    static let urban = WorldTemplate(
        id: "urban",
        name: "都市日常",
        subtitle: "平凡中的不凡",
        emoji: "🏙️",
        previewColor: 0x6366F1,
        description: "都市生活中的小确幸和大冒险。",
        settingPrompt: "现代都市背景，职场、生活、友情、爱情，讲述普通人的不普通故事。",
        openingHooks: [
            "今天是你在新公司上班的第一天...",
            "你租的公寓里出现了一只会说话的猫...",
            "青梅竹马突然说喜欢你，已经十年了..."
        ],
        isPremium: false
    )
    
    static let magicAcademy = WorldTemplate(
        id: "magic_academy",
        name: "魔法学院",
        subtitle: "霍格沃茨般的冒险",
        emoji: "🔮",
        previewColor: 0x8B5CF6,
        description: "你收到了一封来自魔法学院的录取通知书。",
        settingPrompt: "隐藏在现代世界中的魔法学院，学生们学习各种魔法技能。学院里有悠久的历史、神秘的传说和激烈的竞争。",
        openingHooks: [
            "16岁生日那天，你收到了一封 owl 送来的信...",
            "上学的路上，你无意间走进了一个只有魔法世界才有的入口...",
            "你的入学测试结果显示，你拥有百年一遇的特殊能力..."
        ],
        isPremium: true
    )
    
    static let spaceOpera = WorldTemplate(
        id: "space_opera",
        name: "星际歌剧",
        subtitle: "银河中的史诗",
        emoji: "🌌",
        previewColor: 0x1E40AF,
        description: "银河系中的战争、爱情与冒险。",
        settingPrompt: "宏大的星际背景，多个星系、种族、帝国之间的复杂关系。太空舰队、星际战争、跨种族爱情。",
        openingHooks: [
            "你的飞船被不明势力袭击，迫降在一个未知星球...",
            "帝国公主秘密找上你，说要推翻她父亲的统治...",
            "古老的预言说，你是结束银河战争的关键..."
        ],
        isPremium: true
    )
    
    static let postApocalyptic = WorldTemplate(
        id: "post_apocalyptic",
        name: "末日生存",
        subtitle: "废土之上的希望",
        emoji: "☢️",
        previewColor: 0x374151,
        description: "文明崩塌之后，人性还剩下什么？",
        settingPrompt: "核战后或灾难后的废土世界，资源匮乏，危险四伏。幸存者们艰难求生，同时重建文明的希望。",
        openingHooks: [
            "你从地下避难所出来，发现外面的世界已经完全不同...",
            "一群掠夺者抢走了你最后的物资，你必须追回来...",
            "你遇到了一个自称知道'安全区'位置的陌生人..."
        ],
        isPremium: true
    )
    
    static func template(with id: String) -> WorldTemplate? {
        all.first { $0.id == id }
    }
}
