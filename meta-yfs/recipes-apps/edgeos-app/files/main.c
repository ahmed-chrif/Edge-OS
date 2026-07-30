#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/sysinfo.h>

#define PORT 8080
#define APP_VERSION "1.0.0-factory"

void send_json_response(int client_fd)
{
    struct sysinfo info;
    sysinfo(&info);

    long total_ram = info.totalram / (1024 * 1024);
    long free_ram = info.freeram / (1024 * 1024);
    int uptime_min = info.uptime / 60;

    char json_body[512];
    snprintf(json_body, sizeof(json_body),
             "{\n"
             "  \"app\": \"EdgeOS  Daemon\",\n"
             "  \"version\": \"%s\",\n"
             "  \"status\": \"HEALTHY\",\n"
             "  \"uptime_minutes\": %d,\n"
             "  \"total_ram_mb\": %ld,\n"
             "  \"free_ram_mb\": %ld\n"
             "}\n",
             APP_VERSION, uptime_min, total_ram, free_ram);

    char http_response[1024];
    snprintf(http_response, sizeof(http_response),
             "HTTP/1.1 200 OK\r\n"
             "Content-Type: application/json\r\n"
             "Access-Control-Allow-Origin: *\r\n"
             "Content-Length: %zu\r\n"
             "\r\n"
             "%s",
             strlen(json_body), json_body);

    write(client_fd, http_response, strlen(http_response));
}

int main()
{
    int server_fd, new_socket;
    struct sockaddr_in address;
    int opt = 1;
    int addrlen = sizeof(address);

    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0)
    {
        perror("socket failed");
        exit(EXIT_FAILURE);
    }

    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0)
    {
        perror("bind failed");
        exit(EXIT_FAILURE);
    }

    if (listen(server_fd, 3) < 0)
    {
        perror("listen failed");
        exit(EXIT_FAILURE);
    }

    printf("Edge Telemetry Service v%s listening on port %d...\n", APP_VERSION, PORT);

    while (1)
    {
        if ((new_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t *)&addrlen)) < 0)
        {
            continue;
        }
        send_json_response(new_socket);
        close(new_socket);
    }

    return 0;
}