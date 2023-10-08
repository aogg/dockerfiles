package main

import (
    "fmt"
    "log"
    "net/http"
	"io/ioutil"
	"os"
	"regexp"
	"strings"
)

func handler(w http.ResponseWriter, r *http.Request) {
    	// 获取参数
	// 从URL参数中获取ip和host参数的值
	ip := r.URL.Query().Get("ip")
	host := r.URL.Query().Get("host")

	filePath := "/data/hosts" // 根据实际的hosts文件路径进行调整

	// 读取hosts文件内容
	content, err := ioutil.ReadFile(filePath) // 根据操作系统和hosts文件路径进行调整
	if err != nil {
		// 文件不存在，创建新文件
		if os.IsNotExist(err) {
			fmt.Println("hosts文件---创建")
			err = ioutil.WriteFile(filePath, []byte{}, 0644)
			if err != nil {
				fmt.Println("无法创建hosts文件:", err)
				return
			}
			// fmt.Println("hosts文件已创建")
			// return
		} else {
			fmt.Println("无法读取hosts文件:", err)
		}

		// fmt.Println("无法读取hosts文件:", err)
		// return
	}

	// 移除重复的host
	newContent := removeDuplicateHosts(string(content), host)

	// 添加新的host
	newContent += fmt.Sprintf("%s %s\n", ip, host)

	// 写入修改后的内容到hosts文件
	err = ioutil.WriteFile(filePath, []byte(newContent), 0644) // 根据操作系统和hosts文件路径进行调整
	if err != nil {
		fmt.Println("无法写入hosts文件:", err)
		return
	}

	fmt.Fprint(w, "hosts文件已更新")

}

// 从hosts内容中移除重复的host
func removeDuplicateHosts(content, host string) string {
	lines := strings.Split(content, "\n")
	newLines := make([]string, 0)

	// 使用正则表达式匹配host行
	hostPattern := fmt.Sprintf(`^\s*([\d.:]+)\s+%s\s*$`, regexp.QuoteMeta(host))
	hostRegex := regexp.MustCompile(hostPattern)

	// 遍历每行内容
	for _, line := range lines {
		// 检查是否匹配host行
		if !hostRegex.MatchString(line) {
			newLines = append(newLines, line)
		}
	}

	// 拼接新的内容
	return strings.Join(newLines, "\n")
}

func main() {
    http.HandleFunc("/", handler)
    
    log.Println("开启http端口 :8080")

    log.Fatal(http.ListenAndServe(":8080", nil))
}
